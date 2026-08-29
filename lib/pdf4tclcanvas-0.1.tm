# pdf4tclcanvas -- Canvas-Export mit Rahmen, Massstab und Strukturbaum
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Usage:
#   package require pdf4tclcanvas
#   ::pdf4tcllib::canvas::place $pdf $c $x $y $w $h ?-option wert ...?
#
# Requires:
#   pdf4tcllib 0.6.3+, pdf4tcl 0.9.4.25+, Tk
#
# WAS DIESES MODUL TUT UND WAS NICHT
#
# Gezeichnet wird nicht hier: das kann pdf4tcl mit "$pdf canvas" seit
# Langem, fuer tk::canvas, tkpath und tko::path. Wie bei pdf4tcltable
# und pdf4tcltreeview ist dies ein Adapter -- er nimmt dem Aufrufer ab,
# was drumherum haengt und was jeder von Hand falsch macht:
#
#   - DER MASSSTAB. "$pdf canvas" nimmt -width und -height und zieht die
#     Zeichnung darauf. Weicht das Seitenverhaeltnis des Rahmens von dem
#     der Zeichnung ab, verzerrt sie -- genau wie putImage bei einem
#     Bild, und genauso still. place rechnet den Massstab aus der bbox
#     und haelt das Verhaeltnis.
#
#   - DER STRUKTURBAUM. Ein Canvas-Export hinterlaesst Loecher: gemessen
#     an vier Elementen (Rechteck, Ellipse, Linie, Text) drei offene
#     Zeichenbefehle. Eine Zeichnung ist eine Figure, und wenn sie fuer
#     ein Vorleseprogramm etwas bedeuten soll, braucht sie ein -alt.
#     Ohne -alt wird sie als Artefakt gefasst -- Zierrat, aber wenigstens
#     kein Loch.
#
#   - DIE BILDUNTERSCHRIFT. Wie bei image::gallery steht sie INNERHALB
#     der Figure, damit der Baum sagt, wozu der Text gehoert.

package require Tk
package require pdf4tcllib 0.6.3

package provide pdf4tclcanvas 0.1

namespace eval ::pdf4tcllib::canvas {}

# Die bbox eines Canvas, notfalls die Widgetgroesse.
#
# Ein leerer Canvas hat keine bbox -- "$c bbox all" gibt dann nichts
# zurueck, und "$pdf canvas" bricht ab. Hier wird stattdessen die
# Widgetgroesse genommen: eine leere Zeichnung ist kein Fehler.
proc ::pdf4tcllib::canvas::_bbox {c} {
    set bb {}
    catch {set bb [$c bbox all]}
    if {[llength $bb] == 4} { return $bb }
    set w 100 ; set h 100
    catch {set w [winfo width $c]}
    catch {set h [winfo height $c]}
    if {$w <= 1} { catch {set w [$c cget -width]} }
    if {$h <= 1} { catch {set h [$c cget -height]} }
    return [list 0 0 $w $h]
}

# ---------------------------------------------------------------------------
# place -- eine Zeichnung in einen Rahmen setzen
#
#   -fit       contain | stretch   (contain)
#   -anchor    nw n ne w center e sw s se   (center)
#   -alt       Beschreibung fuer den Strukturbaum; ohne sie Artefakt
#   -caption   Bildunterschrift unter der Zeichnung
#   -captionH  Hoehe des Unterschriftenbandes (14)
#   -fontsize  Schriftgroesse der Unterschrift (9)
#   -font      Schrift, sonst die aus fonts::init
#   -bbox      eigene bbox statt "all"
#   -fontmap   an "$pdf canvas" durchgereicht
#   -textscale dito
#   -border    Rahmen um die Zeichnung zeichnen (0)
#
# Rueckgabe: die belegte Flaeche {x y w h}, ohne das Unterschriftenband.
# ---------------------------------------------------------------------------
proc ::pdf4tcllib::canvas::place {pdf c x y w h args} {
    array set o {
        -fit contain -anchor center -alt {} -caption {}
        -captionH 14 -fontsize 9 -font {} -bbox {}
        -fontmap {} -textscale {} -border 0
    }
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "canvas::place: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    if {![winfo exists $c]} {
        return -code error "canvas::place: no such widget: $c"
    }
    if {$o(-fit) ni {contain stretch}} {
        return -code error "canvas::place: -fit must be contain or stretch,\
                not \"$o(-fit)\""
    }
    if {$w <= 0 || $h <= 0} {
        return -code error "canvas::place: width and height must be positive"
    }

    set bb $o(-bbox)
    if {![llength $bb]} { set bb [_bbox $c] }
    lassign $bb bx1 by1 bx2 by2
    set bw [expr {$bx2 - $bx1}]
    set bh [expr {$by2 - $by1}]
    if {$bw <= 0 || $bh <= 0} { set bw 1 ; set bh 1 }

    set capH 0
    if {$o(-caption) ne ""} { set capH $o(-captionH) }
    set rahmenH [expr {$h - $capH}]
    if {$rahmenH <= 0} {
        return -code error "canvas::place: no room left for the drawing\
                after the caption"
    }

    # Der Massstab. Bei contain bestimmt die knappere Richtung ihn, und
    # das Verhaeltnis bleibt erhalten; bei stretch wird gezogen, wie
    # "$pdf canvas" es von sich aus tut.
    if {$o(-fit) eq "contain"} {
        set s [expr {min($w / double($bw), $rahmenH / double($bh))}]
        set zw [expr {$bw * $s}]
        set zh [expr {$bh * $s}]
    } else {
        set zw $w
        set zh $rahmenH
    }
    lassign [_ausrichten $o(-anchor) $x $y $w $rahmenH $zw $zh] zx zy

    # Der Strukturbaum. Mit -alt eine Figure, ohne sie ein Artefakt --
    # eine Zeichnung ohne Beschreibung ist fuer ein Vorleseprogramm
    # nichts wert, aber ein Loch im Baum ist schlimmer als Zierrat.
    set alt $o(-alt)
    if {$alt eq "" && $o(-caption) ne ""} { set alt $o(-caption) }
    if {$alt ne ""} {
        if {[catch {::pdf4tcllib::tag::begin $pdf Figure -alt $alt}]} {
            catch {::pdf4tcllib::tag::begin $pdf Figure}
        }
        set schluss tag
    } else {
        ::pdf4tcllib::tag::artifact $pdf -type Layout
        set schluss artifact
    }

    set canvasArgs [list -bbox $bb -x $zx -y $zy -width $zw -height $zh]
    if {[llength $o(-fontmap)]}   { lappend canvasArgs -fontmap $o(-fontmap) }
    if {$o(-textscale) ne ""}     { lappend canvasArgs -textscale $o(-textscale) }
    $pdf canvas $c {*}$canvasArgs

    if {$o(-border)} {
        ::pdf4tcllib::drawing::frame $pdf $zx $zy $zw $zh 0.5
    }

    if {$o(-caption) ne ""} {
        set font $o(-font)
        if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }
        # Wie in image::gallery: zu breit heisst kleiner setzen, nicht
        # kuerzen.
        set fs [::pdf4tcllib::text::fitSize $o(-caption) $w $o(-fontsize) \
                $font -min 5 -pdf $pdf]
        catch {::pdf4tcllib::tag::begin $pdf Caption}
        $pdf setFont $fs $font
        set tw [::pdf4tcllib::text::width $o(-caption) $fs $font $pdf]
        set tx [expr {$x + ($w - $tw) / 2.0}]
        ::pdf4tcllib::unicode::safeText $pdf $o(-caption) \
                -x $tx -y [expr {$y + $rahmenH + $fs + 2}]
        catch {::pdf4tcllib::tag::end $pdf}
    }

    if {$schluss eq "tag"} {
        catch {::pdf4tcllib::tag::end $pdf}
    } else {
        ::pdf4tcllib::tag::artifactEnd $pdf
    }
    return [list $zx $zy $zw $zh]
}

proc ::pdf4tcllib::canvas::_ausrichten {anchor x y w h zw zh} {
    set dx [expr {$w - $zw}]
    set dy [expr {$h - $zh}]
    switch -- $anchor {
        nw { return [list $x $y] }
        n  { return [list [expr {$x + $dx / 2.0}] $y] }
        ne { return [list [expr {$x + $dx}] $y] }
        w  { return [list $x [expr {$y + $dy / 2.0}]] }
        e  { return [list [expr {$x + $dx}] [expr {$y + $dy / 2.0}]] }
        sw { return [list $x [expr {$y + $dy}]] }
        s  { return [list [expr {$x + $dx / 2.0}] [expr {$y + $dy}]] }
        se { return [list [expr {$x + $dx}] [expr {$y + $dy}]] }
        default { return [list [expr {$x + $dx / 2.0}] \
                               [expr {$y + $dy / 2.0}]] }
    }
}

# ---------------------------------------------------------------------------
# fitPage -- eine Zeichnung auf die ganze Seite
#
# Der haeufigste Fall: ein Schaubild, das eine Seite fuellen soll, mit den
# Raendern aus dem Seitenkontext. Nimmt dieselben Optionen wie place.
# ---------------------------------------------------------------------------
proc ::pdf4tcllib::canvas::fitPage {pdf c ctx args} {
    # SX/SY/SW/SH ist der Satzspiegel, wie ihn page::context liefert --
    # dieselben Werte, mit denen table::draw und forms:: rechnen.
    set x  [dict get $ctx SX]
    set y  [dict get $ctx SY]
    set w  [dict get $ctx SW]
    set h  [dict get $ctx SH]
    if {$h <= 0} {
        return -code error "canvas::fitPage: the context leaves no height"
    }
    return [place $pdf $c $x $y $w $h {*}$args]
}
