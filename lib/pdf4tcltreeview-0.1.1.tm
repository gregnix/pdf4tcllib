# pdf4tcltreeview -- ttk::treeview-Widget Export nach PDF
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Usage:
#   package require pdf4tcltreeview
#   ::pdf4tcllib::treeview::render $pdf $tv $x $y ?-option wert ...?
#
# Requires:
#   pdf4tcllib 0.6.3+, pdf4tcl 0.9.4.25+, Tk
#
# WARUM EIN EIGENES MODUL UND KEIN NEUER ZEICHNER
#
# Ein treeview ist zweierlei zugleich: eine Tabelle mit Spalten UND ein
# Baum. Als Tabelle kann ihn ::pdf4tcllib::table::draw bereits zeichnen,
# Einrueckung eingeschlossen -- dafuer gibt es dort -rowindent, und der
# tablelist-Exporteur benutzt es seit 0.3 fuer seinen Baum-Modus. Dieses
# Modul ist deshalb ein duenner Adapter wie pdf4tcltable: Widget lesen,
# umformen, weiterreichen. Kein zweiter Zeichner.
#
# WAS DER AUFRUFER ENTSCHEIDEN MUSS
#
# Beim Tagging gehen die beiden Lesarten auseinander: eine Tabelle ist
# Table/TR/TD, eine Gliederung L/LI/LBody. Was gilt, kann das Modul nicht
# erraten -- ein treeview mit drei Wertespalten ist eine Tabelle, einer
# mit nur der Baumspalte eine Liste. Hier wird die TABELLE gezeichnet,
# weil das die Darstellung ist, die man auf dem Papier wiedererkennt.
# Wer eine Gliederung braucht, hat mit toc::heading und den Lesezeichen
# den passenderen Weg.
#
# DIE BAUMSPALTE
#
# ttk::treeview haelt den Baum in Spalte "#0", getrennt von den
# Wertespalten. -text steht in #0, -values in den uebrigen. Ist #0
# ausgeblendet (-show headings ohne tree), gibt es keine Baumspalte, und
# der Export ist eine gewoehnliche Tabelle.

package require Tk
package require pdf4tcllib 0.6.3

package provide pdf4tcltreeview 0.1.1

namespace eval ::pdf4tcllib::treeview {}

proc ::pdf4tcllib::treeview::_checkOpts {who defaults args_} {
    array set known $defaults
    foreach {k v} $args_ {
        if {![info exists known($k)]} {
            return -code error "$who: unknown option $k\
                    (known: [join [lsort [array names known]] { }])"
        }
    }
}

# Zeigt das Widget die Baumspalte?
proc ::pdf4tcllib::treeview::_hasTree {tv} {
    set show [$tv cget -show]
    # -show ist eine Liste aus "tree" und "headings"; die Vorgabe {tree
    # headings} zeigt beides.
    return [expr {"tree" in $show}]
}

# Alle sichtbaren Knoten in der Reihenfolge, in der sie auf dem Schirm
# stehen -- also in der Tiefe nur, wo der Knoten offen ist.
#
# Ein geschlossener Knoten wird MITGENOMMEN, seine Kinder nicht: das PDF
# soll zeigen, was zu sehen war. Wer alles will, oeffnet vorher oder
# nimmt -all 1.
proc ::pdf4tcllib::treeview::_walk {tv knoten tiefe allesVar} {
    upvar 1 $allesVar alles
    set out {}
    foreach kind [$tv children $knoten] {
        lappend out [list $kind $tiefe]
        set offen 0
        catch {set offen [$tv item $kind -open]}
        if {$alles || $offen} {
            foreach e [_walk $tv $kind [expr {$tiefe + 1}] alles] {
                lappend out $e
            }
        }
    }
    return $out
}

# Spalten und Zeilen aus dem Widget lesen.
#
# Rueckgabe: dict mit cols, data, rowindent.
proc ::pdf4tcllib::treeview::_extract {tv opts} {
    upvar 1 $opts o

    set mitBaum [expr {$o(-tree) && [_hasTree $tv]}]

    # -- Spalten --
    set cols {}
    set displaycolumns [$tv cget -displaycolumns]
    set alle [$tv cget -columns]
    if {$displaycolumns eq "#all" || $displaycolumns eq ""} {
        set spalten $alle
    } else {
        set spalten $displaycolumns
    }

    # Breiten des Widgets sind Pixel; sie werden auf -maxwidth
    # heruntergerechnet, damit das Verhaeltnis erhalten bleibt. Ein
    # treeview meldet die eingestellte Breite auch dann, wenn die Spalte
    # schmaler dargestellt wird -- das genuegt hier.
    set pixel {}
    set summe 0
    if {$mitBaum} {
        set w 200
        catch {set w [$tv column #0 -width]}
        lappend pixel $w
        incr summe $w
    }
    foreach c $spalten {
        set w 100
        catch {set w [$tv column $c -width]}
        lappend pixel $w
        incr summe $w
    }
    if {$summe <= 0} { set summe 1 }

    set i 0
    if {$mitBaum} {
        set titel ""
        catch {set titel [$tv heading #0 -text]}
        lappend cols [list -header $titel -align left \
                -width [_breite [lindex $pixel 0] $summe $o(-maxwidth)]]
        set i 1
    }
    foreach c $spalten {
        set titel $c
        catch {set titel [$tv heading $c -text]}
        set align left
        catch {set align [$tv column $c -anchor]}
        lappend cols [list -header $titel -align [_anker $align] \
                -width [_breite [lindex $pixel $i] $summe $o(-maxwidth)]]
        incr i
    }

    # -- Zeilen --
    set alles $o(-all)
    set knoten [_walk $tv {} 0 alles]
    set data {}
    set rowindent {}
    set r 0
    foreach e $knoten {
        lassign $e id tiefe
        set zeile {}
        if {$mitBaum} {
            set t ""
            catch {set t [$tv item $id -text]}
            lappend zeile $t
        }
        set werte {}
        catch {set werte [$tv item $id -values]}
        foreach c $spalten {
            set idx [lsearch -exact $alle $c]
            if {$idx >= 0 && [llength $werte] > $idx} {
                lappend zeile [lindex $werte $idx]
            } else {
                lappend zeile ""
            }
        }
        lappend data $zeile
        # -rowindent ist ein Dict Zeilennummer -> Punkte, kein Vektor:
        # nur Zeilen, die wirklich eingerueckt sind, stehen darin. Und
        # eingerueckt wird nur, wenn die Baumspalte gezeigt wird -- ohne
        # sie steht der Text in der ersten Wertespalte, und eine
        # Einrueckung dort waere eine Aussage ueber Daten, die das Widget
        # nicht macht.
        if {$mitBaum && $tiefe > 0} {
            dict set rowindent $r [expr {$tiefe * $o(-indentW)}]
        }
        incr r
    }

    return [dict create cols $cols data $data rowindent $rowindent]
}

proc ::pdf4tcllib::treeview::_breite {pixel summe maxW} {
    return [expr {max(18, int($maxW * $pixel / double($summe)))}]
}

# ttk-Anker auf die Ausrichtung, die table::draw kennt.
proc ::pdf4tcllib::treeview::_anker {anchor} {
    switch -glob -- $anchor {
        e - se - ne { return right }
        center - n - s { return center }
        default { return left }
    }
}

# --------------------------------------------------------------------------
# render -- das ganze Widget, so wie es zu sehen ist
#
#   -maxwidth   Breite der Tabelle in Punkt (Vorgabe 480)
#   -fontsize   Schriftgroesse (9)
#   -rowheight  Zeilenhoehe in Punkt; 0 = aus der Schriftgroesse
#   -tree       Baumspalte einruecken (1); 0 zeichnet flach
#   -all        auch geschlossene Aeste (0)
#   -zebra      Zebrastreifen (1)
#   -border     Gitterlinien (1)
#   -indentW    Einrueckung je Ebene in Punkt (12)
#   -ctx        Seitenkontext aus page::context
#   -yvar       Variable, die das y nach der Tabelle bekommt
#   -pagevar    Variable mit der Seitenzahl
#   -font/-boldfont  Schriften, sonst die aus fonts::init
#
# Rueckgabe: das y nach der letzten Zeile.
# --------------------------------------------------------------------------
proc ::pdf4tcllib::treeview::render {pdf tv x y args} {
    array set opts {
        -maxwidth 480  -fontsize 9   -rowheight 0
        -tree     1    -all      0   -zebra     1
        -border   1    -indentW  12  -ctx       {}
        -yvar     {}   -pagevar  {}  -font      {}
        -boldfont {}   -summary  {}
    }
    _checkOpts ::pdf4tcllib::treeview::render [array get opts] $args
    array set opts $args

    if {![winfo exists $tv]} {
        return -code error "treeview::render: no such widget: $tv"
    }

    set fs $opts(-fontsize)
    set rh $opts(-rowheight)
    if {$rh <= 0} { set rh [expr {int($fs * 1.8)}] }

    set ex [_extract $tv opts]
    if {![llength [dict get $ex cols]]} { return $y }

    if {$opts(-pagevar) ne ""} {
        upvar 1 $opts(-pagevar) callerPage
        set pageLocal $callerPage
    } else {
        set pageLocal 1
    }

    set drawArgs [list \
        -maxwidth $opts(-maxwidth) -fontsize $fs -rowheight $rh -pad 3 \
        -border $opts(-border) -header 1 -zebra $opts(-zebra) \
        -rowindent [dict get $ex rowindent] -pagevar pageLocal]
    if {$opts(-ctx)      ne ""} { lappend drawArgs -ctx      $opts(-ctx) }
    if {$opts(-font)     ne ""} { lappend drawArgs -fontreg  $opts(-font) }
    if {$opts(-boldfont) ne ""} { lappend drawArgs -fontbold $opts(-boldfont) }
    if {$opts(-summary)  ne ""} { lappend drawArgs -summary  $opts(-summary) }

    set yend [::pdf4tcllib::table::draw $pdf $x $y \
                  [dict get $ex cols] [dict get $ex data] {*}$drawArgs]

    if {$opts(-pagevar) ne ""} { set callerPage $pageLocal }
    if {$opts(-yvar)    ne ""} { upvar 1 $opts(-yvar) yret; set yret $yend }
    return $yend
}

# --------------------------------------------------------------------------
# outline -- die Baumspalte allein, als eingerueckte Liste mit Lesezeichen
#
# Fuer den Fall, dass der Baum das Thema ist und die Wertespalten nicht.
# Jeder Knoten bekommt ein Lesezeichen, so tief verschachtelt wie im
# Widget -- damit ist der Baum im Leser navigierbar, was eine Tabelle
# nicht leistet.
#
#   -fontsize   Schriftgroesse (10)
#   -indentW    Einrueckung je Ebene in Punkt (14)
#   -lineH      Zeilenabstand; 0 = aus der Schriftgroesse
#   -all        auch geschlossene Aeste (0)
#   -bookmarks  Lesezeichen setzen (1)
#   -yvar       Variable, die das y nach der Liste bekommt
#
# Rueckgabe: das y nach der letzten Zeile.
# --------------------------------------------------------------------------
proc ::pdf4tcllib::treeview::outline {pdf tv x y args} {
    array set opts {
        -fontsize 10  -indentW 14  -lineH 0
        -all      0   -bookmarks 1 -yvar {}
        -font     {}
    }
    _checkOpts ::pdf4tcllib::treeview::outline [array get opts] $args
    array set opts $args

    if {![winfo exists $tv]} {
        return -code error "treeview::outline: no such widget: $tv"
    }

    set fs $opts(-fontsize)
    set lh $opts(-lineH)
    if {$lh <= 0} { set lh [expr {$fs * 1.4}] }
    set font $opts(-font)
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }

    set alles $opts(-all)
    set knoten [_walk $tv {} 0 alles]

    # L/LI/LBody ist die Rolle einer Gliederung -- hier stimmt sie, anders
    # als beim Tabellen-Export oben.
    ::pdf4tcllib::tag::begin $pdf L
    $pdf setFont $fs $font
    foreach e $knoten {
        lassign $e id tiefe
        set t ""
        catch {set t [$tv item $id -text]}
        if {$t eq ""} {
            catch {set t [lindex [$tv item $id -values] 0]}
        }
        set tx [expr {$x + $tiefe * $opts(-indentW)}]
        ::pdf4tcllib::tag::begin $pdf LI
        ::pdf4tcllib::tag::begin $pdf LBody
        ::pdf4tcllib::unicode::safeText $pdf $t -x $tx -y $y
        ::pdf4tcllib::tag::end $pdf
        ::pdf4tcllib::tag::end $pdf
        if {$opts(-bookmarks) && [string trim $t] ne ""} {
            # bookmarkAdd nimmt -title und -level; die Ebene zaehlt ab 0
            # wie die Tiefe im Baum. Bis 0.1 stand hier die Ebene als
            # erstes Wort, pdf4tcl warf "unknown option", und catch
            # verschluckte es: kein einziges Lesezeichen.
            $pdf bookmarkAdd -title [::pdf4tcllib::unicode::sanitize $t] \
                    -level $tiefe
        }
        set y [expr {$y + $lh}]
    }
    ::pdf4tcllib::tag::end $pdf

    if {$opts(-yvar) ne ""} { upvar 1 $opts(-yvar) yret; set yret $y }
    return $y
}
