# pdf4tcltable -- Tablelist-Widget Export nach PDF
#
# Exportiert Tk tablelist-Widgets (package tablelist_tile,
# Csaba Nemethi) als formatierte PDF-Tabellen.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Verwendung:
#   package require pdf4tcltable
#   pdf4tcltable::render $pdf $tbl $x $y ...
#
# Abhaengigkeiten:
#   pdf4tcllib 0.4+, pdf4tcl 0.9.4.25+, tablelist_tile
#
# Ab 0.3: duenner Adapter -- liest das Widget aus und delegiert an den
# Tk-freien Renderer ::pdf4tcllib::table::draw. render und renderRange teilen
# sich die Extraktion (_extract). Ausgabe kompatibel zu 0.2.

package require pdf4tcllib 0.4

package provide pdf4tcltable 0.3

namespace eval ::pdf4tcllib::tablelist {}

# --------------------------------------------------------------------------
# _extract -- liest sichtbare Spalten und Zeilen [first..last] aus dem Widget
# und baut cols/data/Styles fuer ::pdf4tcllib::table::draw.
# Rueckgabe: dict mit cols data cellstyles rowstyles rowindent zebra zebracolor
#            hbg hfg vis
# --------------------------------------------------------------------------
proc ::pdf4tcllib::tablelist::_extract {tbl opts first last} {
    upvar 1 $opts o

    # sichtbare Spalten
    set ncols [$tbl columncount]
    set vis {}; set colAligns {}; set chW {}
    for {set c 0} {$c < $ncols} {incr c} {
        set hide 0; catch {set hide [$tbl columncget $c -hide]}
        if {$hide} continue
        set align left; catch {set align [$tbl columncget $c -align]}
        set wch 5; catch {
            set wch [$tbl columncget $c -width]
            if {$wch < 0} { set wch [expr {-$wch}] }
            if {$wch == 0} { set wch 5 }
        }
        lappend vis $c; lappend colAligns $align; lappend chW $wch
    }
    if {[llength $vis] == 0} {
        return [dict create cols {} data {} cellstyles {} rowstyles {} \
                    rowindent {} zebra 0 zebracolor {} hbg {} hfg {} vis {}]
    }

    # ch -> pt (proportional zu -maxwidth, wie 0.2)
    set totalCh 0; foreach w $chW { incr totalCh $w }
    set cols {}
    foreach w $chW al $colAligns c $vis {
        set pw [expr {max(18, int($o(-maxwidth) * $w / double($totalCh)))}]
        set title ""; catch {set title [$tbl columncget $c -title]}
        lappend cols [list -header $title -align $al -width $pw]
    }

    # Daten
    set allRows {}
    if {$o(-formatted)} { catch {set allRows [$tbl getformatted 0 end]} }
    if {[llength $allRows] == 0} { catch {set allRows [$tbl get 0 end]} }

    set nrows [$tbl size]
    if {$last < 0 || $last eq "end" || $last >= $nrows} { set last [expr {$nrows - 1}] }
    if {$first < 0} { set first 0 }

    set data {}; set cellstyles {}; set rowstyles {}; set rowindent {}
    set outR 0
    for {set r $first} {$r <= $last} {incr r} {
        set hide 0; catch {set hide [$tbl rowcget $r -hide]}
        if {$hide} continue
        set rowData [lindex $allRows $r]

        set rstyle {}
        catch {set b [$tbl rowcget $r -background]
               if {$b ne ""} { lappend rstyle -bg [_tkColorToRGB $b] }}
        catch {set f [$tbl rowcget $r -foreground]
               if {$f ne ""} { lappend rstyle -fg [_tkColorToRGB $f] }}
        catch {set ft [$tbl rowcget $r -font]
               if {$ft ne ""} { lappend rstyle -font [_fontKw $ft] }}
        if {[llength $rstyle]} { dict set rowstyles $outR $rstyle }

        if {$o(-tree)} {
            set d 0; catch {set d [$tbl depth $r]}
            set ind [expr {max(0, $d - 1) * $o(-indentW)}]
            if {$ind > 0} { dict set rowindent $outR $ind }
        }

        set rowCells {}
        set outC 0
        foreach c $vis {
            set ct ""
            if {[llength $rowData] > $c} { set ct [lindex $rowData $c] }
            catch {set t2 [$tbl cellcget $r,$c -text]; if {$t2 ne ""} {set ct $t2}}
            lappend rowCells $ct

            set cstyle {}
            catch {set b [$tbl cellcget $r,$c -background]
                   if {$b ne ""} { lappend cstyle -bg [_tkColorToRGB $b] }}
            catch {set fg [$tbl cellcget $r,$c -foreground]
                   if {$fg ne ""} { lappend cstyle -fg [_tkColorToRGB $fg] }}
            catch {set cf [$tbl cellcget $r,$c -font]
                   if {$cf ne ""} { lappend cstyle -font [_fontKw $cf] }}
            if {[llength $cstyle]} { dict set cellstyles "$outR,$outC" $cstyle }
            incr outC
        }
        lappend data $rowCells
        incr outR
    }

    # Zebra
    set zebra 0; set zc {}
    if {$o(-zebra)} {
        set zebra 1
        catch {set s [$tbl cget -stripebackground]
               if {$s ne ""} { set zc [_tkColorToRGB $s] }}
        if {$zc eq ""} { set zc {0.96 0.96 0.96} }
    }

    # Kopf-Farben
    set hbg $o(-headerbg)
    if {$hbg eq ""} {
        set hbg {0.82 0.86 0.94}
        catch {set lb [$tbl columncget [lindex $vis 0] -labelbackground]
               if {$lb ne ""} { set hbg [_tkColorToRGB $lb] }}
    }
    set hfg $o(-headerfg)
    if {$hfg eq ""} {
        set hfg {0 0 0}
        catch {set lf [$tbl columncget [lindex $vis 0] -labelforeground]
               if {$lf ne ""} { set hfg [_tkColorToRGB $lf] }}
    }

    return [dict create cols $cols data $data cellstyles $cellstyles \
                rowstyles $rowstyles rowindent $rowindent \
                zebra $zebra zebracolor $zc hbg $hbg hfg $hfg vis $vis]
}

# --------------------------------------------------------------------------
# render -- ganze Tabelle. Mit -ctx: Auto-Seitenumbruch (Kopf pro Seite).
# --------------------------------------------------------------------------
proc ::pdf4tcllib::tablelist::render {pdf tbl x y args} {
    array set opts {
        -maxwidth  480  -fontsize  9   -rowheight 0
        -zebra     1    -border    1   -tree      1
        -indentW   12   -formatted 1   -yvar      {}
        -ctx       {}   -headerbg  {}  -headerfg  {}
        -footer    {}   -footerbg  {}  -footerbold 1
        -font      {}   -boldfont  {}  -pagevar   {}
    }
    array set opts $args
    set fs $opts(-fontsize)
    set rh $opts(-rowheight)
    if {$rh <= 0} { set rh [expr {int($fs * 1.8)}] }

    set ex [_extract $tbl opts 0 -1]
    if {![llength [dict get $ex vis]]} { return $y }
    set vis [dict get $ex vis]

    # Footer (Widget oder Werteliste)
    set footerVals {}
    if {$opts(-footer) ne ""} {
        set fw $opts(-footer)
        if {[llength $fw] == 1 && [winfo exists $fw] && ![catch {$fw size}]} {
            catch {set footerVals [$fw get 0]}
            catch {set fv2 [$fw getformatted 0]; if {[llength $fv2]} {set footerVals $fv2}}
            if {$opts(-footerbg) eq ""} {
                catch {set b [$fw rowcget 0 -background]
                       if {$b ne ""} { set opts(-footerbg) [_tkColorToRGB $b] }}
            }
        } else {
            set footerVals $fw
        }
        if {[llength $footerVals]} {
            set fv {}
            foreach c $vis {
                lappend fv [expr {[llength $footerVals] > $c ? [lindex $footerVals $c] : ""}]
            }
            set footerVals $fv
        }
    }
    set footerbg $opts(-footerbg)
    if {$footerbg eq ""} { set footerbg {0.90 0.90 0.90} }

    if {$opts(-pagevar) ne ""} {
        upvar 1 $opts(-pagevar) callerPage
        set pageLocal $callerPage
    } else {
        set pageLocal 1
    }

    set drawArgs [list \
        -maxwidth $opts(-maxwidth) -fontsize $fs -rowheight $rh -pad 3 \
        -border $opts(-border) -header 1 \
        -headerbg [dict get $ex hbg] -headerfg [dict get $ex hfg] \
        -zebra [dict get $ex zebra] -zebracolor [dict get $ex zebracolor] \
        -cellstyles [dict get $ex cellstyles] -rowstyles [dict get $ex rowstyles] \
        -rowindent [dict get $ex rowindent] -pagevar pageLocal]
    if {$opts(-ctx) ne ""} { lappend drawArgs -ctx $opts(-ctx) }
    if {[llength $footerVals]} {
        lappend drawArgs -footer $footerVals -footerbg $footerbg \
                         -footerbold $opts(-footerbold)
    }

    set yend [::pdf4tcllib::table::draw $pdf $x $y \
                  [dict get $ex cols] [dict get $ex data] {*}$drawArgs]

    if {$opts(-pagevar) ne ""} { set callerPage $pageLocal }
    if {$opts(-yvar)    ne ""} { upvar 1 $opts(-yvar) yret; set yret $yend }
    return $yend
}

# --------------------------------------------------------------------------
# renderRange -- nur Zeilen -firstrow..-lastrow (fuer manuelle Pagination).
# Zeichnet je Aufruf eine Kopfzeile; kein Footer, kein Auto-Umbruch.
# --------------------------------------------------------------------------
proc ::pdf4tcllib::tablelist::renderRange {pdf tbl x y args} {
    array set opts {
        -maxwidth  480  -fontsize  9   -rowheight 0
        -zebra     1    -border    1   -tree      1
        -indentW   12   -formatted 1   -firstrow  0
        -lastrow   -1   -yvar      {}  -ctx       {}
        -headerbg  {}   -headerfg  {}  -font {} -boldfont {}
    }
    array set opts $args
    set fs $opts(-fontsize)
    set rh $opts(-rowheight)
    if {$rh <= 0} { set rh [expr {int($fs * 1.8)}] }

    set ex [_extract $tbl opts $opts(-firstrow) $opts(-lastrow)]
    if {![llength [dict get $ex vis]]} { return $y }

    # Zebra-Phase an die absolute Startzeile koppeln (wie 0.2)
    set zstart [expr {$opts(-firstrow) % 2}]

    set drawArgs [list \
        -maxwidth $opts(-maxwidth) -fontsize $fs -rowheight $rh -pad 3 \
        -border $opts(-border) -header 1 \
        -headerbg [dict get $ex hbg] -headerfg [dict get $ex hfg] \
        -zebra [dict get $ex zebra] -zebracolor [dict get $ex zebracolor] \
        -zebrastart $zstart \
        -cellstyles [dict get $ex cellstyles] -rowstyles [dict get $ex rowstyles] \
        -rowindent [dict get $ex rowindent]]

    set yend [::pdf4tcllib::table::draw $pdf $x $y \
                  [dict get $ex cols] [dict get $ex data] {*}$drawArgs]

    if {$opts(-yvar) ne ""} { upvar 1 $opts(-yvar) yret; set yret $yend }
    return $yend
}

# --------------------------------------------------------------------------
# Hilfen
# --------------------------------------------------------------------------

# Tk-Farbe -> {r g b} in 0..1 (Hex direkt, sonst winfo rgb).
proc ::pdf4tcllib::tablelist::_tkColorToRGB {color} {
    if {[regexp {^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$} \
            $color -> rh gh bh]} {
        return [list [expr {"0x$rh"/255.0}] \
                     [expr {"0x$gh"/255.0}] \
                     [expr {"0x$bh"/255.0}]]
    }
    if {[regexp {^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$} \
            $color -> rh gh bh]} {
        return [list [expr {"0x${rh}${rh}"/255.0}] \
                     [expr {"0x${gh}${gh}"/255.0}] \
                     [expr {"0x${bh}${bh}"/255.0}]]
    }
    if {![catch {set rgb [winfo rgb . $color]}]} {
        lassign $rgb r g b
        return [list [expr {$r/65535.0}] [expr {$g/65535.0}] [expr {$b/65535.0}]]
    }
    return {0.0 0.0 0.0}
}

# Tk-Font-Spec -> Schluesselwort fuer table::draw (reg|bold|italic|bolditalic|mono).
proc ::pdf4tcllib::tablelist::_fontKw {spec} {
    set s [string tolower $spec]
    set bold [expr {[string match *bold* $s]}]
    set ital [expr {[string match *italic* $s] || [string match *oblique* $s]}]
    set mono [expr {[string match *courier* $s] || [string match *mono* $s] \
                    || [string match *consol* $s]}]
    if {$mono} { return mono }
    if {$bold && $ital} { return bolditalic }
    if {$bold} { return bold }
    if {$ital} { return italic }
    return reg
}

# --- Aliase (wie im Manual versprochen) ---
namespace eval ::pdf4tcltable {}
interp alias {} ::pdf4tcltable::render      {} ::pdf4tcllib::tablelist::render
interp alias {} ::pdf4tcltable::renderRange {} ::pdf4tcllib::tablelist::renderRange
