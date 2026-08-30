# pdf4tcltable -- Tablelist-Widget Export nach PDF
#
# Exportiert Tk tablelist-Widgets (package tablelist_tile,
# Csaba Nemethi) als formatierte PDF-Tabellen.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Usage:
#   package require pdf4tcltable
#   pdf4tcltable::render $pdf $tbl $x $y ...
#
# Requires:
#   pdf4tcllib 0.4+, pdf4tcl 0.9.4.25+, tablelist_tile
#
# Since 0.3 this is a thin adapter: it reads the widget and delegates to the
# Tk-free renderer ::pdf4tcllib::table::draw. render and renderRange share the
# extraction (_extract). Output stays compatible with 0.2.

package require pdf4tcllib 0.4

package provide pdf4tcltable 0.3.2

namespace eval ::pdf4tcllib::tablelist {}

# --------------------------------------------------------------------------
# _extract -- read the visible columns and rows [first..last] from the widget
# and build cols/data/styles for ::pdf4tcllib::table::draw.
# Returns: dict with cols data cellstyles rowstyles rowindent zebra zebracolor
#          hbg hfg vis
# --------------------------------------------------------------------------
# Was der Export NICHT uebertragen kann.
#
# Der Sinn dieses Exporteurs ist: was auf dem Bildschirm steht, kommt ins
# PDF -- in der Reihenfolge, in der es dort steht. Drei Dinge kann er
# nicht, und bis 0.3.1 verschwanden sie lautlos:
#
#   Bild in einer Zelle        cellconfigure -image
#   eingebettetes Fenster      cellconfigure -window
#   umbrechende Spalte         columnconfigure -wrap 1 -- im Widget steht
#                              der Text mehrzeilig, im PDF eine Zeile mit
#                              "...", weil table::draw nicht umbricht
#
# Gemessen an einer Spalte mit -wrap 1 und einem 82 Zeichen langen Text:
# das Widget zeigt ihn ganz, das PDF endet nach 41 Zeichen mit "...".
#
# Gezaehlt wird jetzt, und einmal je Lauf gesagt. Der Bericht steht
# danach in ::pdf4tcllib::tablelist::report.
namespace eval ::pdf4tcllib::tablelist {
    variable _fehlt
    array set _fehlt {}
}

# Was beim letzten render nicht uebertragen wurde:
#   {images N windows N wrapped N cells {0,2 1,0 ...}}
proc ::pdf4tcllib::tablelist::report {} {
    variable _fehlt
    return [array get _fehlt]
}

proc ::pdf4tcllib::tablelist::_resetReport {} {
    variable _fehlt
    array unset _fehlt
    array set _fehlt {images 0 windows 0 wrapped 0 cells {}}
    return
}

proc ::pdf4tcllib::tablelist::_vermerk {art zelle} {
    variable _fehlt
    if {![info exists _fehlt($art)]} { set _fehlt($art) 0 }
    incr _fehlt($art)
    # Hoechstens zwoelf Zellen festhalten -- die Liste soll sagen WO,
    # nicht jedes Vorkommen protokollieren.
    if {[llength $_fehlt(cells)] < 12 &&
            [lsearch -exact $_fehlt(cells) $zelle] < 0} {
        lappend _fehlt(cells) $zelle
    }
    return
}

# Einmal je Lauf sagen, was nicht mitkam. Der Zaehler allein hilft nur
# dem, der ihn abfragt -- und wer nicht weiss, dass es ihn gibt, fragt
# nicht.
proc ::pdf4tcllib::tablelist::_sagWasFehlt {} {
    variable _fehlt
    set teile {}
    foreach {art wort} {images "cell image" windows "embedded window"
            wrapped "wrapped column"} {
        if {[info exists _fehlt($art)] && $_fehlt($art) > 0} {
            lappend teile "$_fehlt($art) x $wort"
        }
    }
    if {![llength $teile]} { return }
    lappend ::pdf4tcl::warnings "tablelist::render: [join $teile {, }] could\
            not be reproduced ([join [lrange $_fehlt(cells) 0 3] {, }]).\
            A cell image or an embedded window is not drawn at all; a\
            wrapped column is shortened to one line, because table::draw\
            does not wrap. Ask ::pdf4tcllib::tablelist::report for the\
            full list."
    return
}

proc ::pdf4tcllib::tablelist::_extract {tbl opts first last} {
    upvar 1 $opts o
    _resetReport

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
        set wrap 0; catch {set wrap [$tbl columncget $c -wrap]}
        lappend vis $c; lappend colAligns $align; lappend chW $wch
        lappend colWrap $wrap
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
            # cellcget -text liefert den ROHEN Wert und ueberschrieb damit
            # den formatierten aus getformatted -- -formatted 1 hatte
            # keine Wirkung, seit es die Option gibt. Gemessen an einer
            # Spalte mit -formatcommand: im PDF stand 1 statt "ja", mit
            # -formatted 1 wie mit 0.
            #
            # Ohne Formatierung bleibt der Zugriff noetig: dort holt er
            # Text, den der Aufrufer per cellconfigure -text gesetzt hat.
            if {!$o(-formatted)} {
                catch {set t2 [$tbl cellcget $r,$c -text]
                       if {$t2 ne ""} {set ct $t2}}
            }
            lappend rowCells $ct

            # Was hier nicht mitkommt, wird gezaehlt statt verschwiegen.
            set bild ""
            catch {set bild [$tbl cellcget $r,$c -image]}
            if {$bild ne ""} { _vermerk images "$r,$c" }
            set fenster ""
            catch {set fenster [$tbl cellcget $r,$c -window]}
            if {$fenster ne ""} { _vermerk windows "$r,$c" }
            # Eine umbrechende Spalte allein ist noch kein Verlust --
            # "kurz" passt auch dort in eine Zeile. Gemeldet wird nur,
            # was laenger ist als die Spalte breit ist. Das ist eine
            # Schaetzung ueber die Zeichenzahl, keine Messung: die
            # genaue Breite kennt erst table::draw.
            set idx [lsearch -exact $vis $c]
            if {[lindex $colWrap $idx] &&
                    [string length $ct] > [lindex $chW $idx]} {
                _vermerk wrapped "$r,$c"
            }

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
# render -- the whole table. With -ctx: automatic page breaks, header per page.
# --------------------------------------------------------------------------
# Rejects an option the caller made up. Without this, `array set opts $args`
# accepts every key: a typo, a renamed option or an option this version does
# not implement is silently stored and never read. Measured 2026-08-15:
# `-quatsch 1` went through pdf4tcltable::render without a word.
proc ::pdf4tcllib::tablelist::_checkOpts {who defaults args_} {
    if {[llength $args_] % 2} {
        return -code error "$who: expected an even number of option/value words"
    }
    foreach {key val} $args_ {
        if {![dict exists $defaults $key]} {
            return -code error \
                "$who: unknown option $key (allowed: [join [lsort [dict keys $defaults]] { }])"
        }
    }
}

proc ::pdf4tcllib::tablelist::render {pdf tbl x y args} {
    array set opts {
        -maxwidth  480  -fontsize  9   -rowheight 0
        -zebra     1    -border    1   -tree      1
        -indentW   12   -formatted 1   -yvar      {}
        -ctx       {}   -headerbg  {}  -headerfg  {}
        -footer    {}   -footerbg  {}  -footerbold 1
        -font      {}   -boldfont  {}  -pagevar   {}
    }
    _checkOpts ::pdf4tcllib::tablelist::render [array get opts] $args
    array set opts $args
    set fs $opts(-fontsize)
    set rh $opts(-rowheight)
    if {$rh <= 0} { set rh [expr {int($fs * 1.8)}] }

    set ex [_extract $tbl opts 0 -1]
    if {![llength [dict get $ex vis]]} { return $y }
    _sagWasFehlt
    set vis [dict get $ex vis]

    # Footer: either a widget or a list of values
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

    # -font / -boldfont were accepted and never applied until 0.3. They now
    # go to table::draw as -fontreg/-fontbold; empty still means the face
    # set loaded by fonts::init.
    if {$opts(-font)     ne ""} { lappend drawArgs -fontreg  $opts(-font) }
    if {$opts(-boldfont) ne ""} { lappend drawArgs -fontbold $opts(-boldfont) }

    set yend [::pdf4tcllib::table::draw $pdf $x $y \
                  [dict get $ex cols] [dict get $ex data] {*}$drawArgs]

    if {$opts(-pagevar) ne ""} { set callerPage $pageLocal }
    if {$opts(-yvar)    ne ""} { upvar 1 $opts(-yvar) yret; set yret $yend }
    return $yend
}

# --------------------------------------------------------------------------
# renderRange -- rows -firstrow..-lastrow only, for hand-made pagination.
# Draws a header row per call; no footer, no automatic page break.
# --------------------------------------------------------------------------
proc ::pdf4tcllib::tablelist::renderRange {pdf tbl x y args} {
    array set opts {
        -maxwidth  480  -fontsize  9   -rowheight 0
        -zebra     1    -border    1   -tree      1
        -indentW   12   -formatted 1   -firstrow  0
        -lastrow   -1   -yvar      {}  -ctx       {}
        -headerbg  {}   -headerfg  {}  -font {} -boldfont {}
    }
    _checkOpts ::pdf4tcllib::tablelist::renderRange [array get opts] $args
    array set opts $args
    set fs $opts(-fontsize)
    set rh $opts(-rowheight)
    if {$rh <= 0} { set rh [expr {int($fs * 1.8)}] }

    set ex [_extract $tbl opts $opts(-firstrow) $opts(-lastrow)]
    if {![llength [dict get $ex vis]]} { return $y }

    # Tie the zebra phase to the absolute first row, as 0.2 did
    set zstart [expr {$opts(-firstrow) % 2}]

    set drawArgs [list \
        -maxwidth $opts(-maxwidth) -fontsize $fs -rowheight $rh -pad 3 \
        -border $opts(-border) -header 1 \
        -headerbg [dict get $ex hbg] -headerfg [dict get $ex hfg] \
        -zebra [dict get $ex zebra] -zebracolor [dict get $ex zebracolor] \
        -zebrastart $zstart \
        -cellstyles [dict get $ex cellstyles] -rowstyles [dict get $ex rowstyles] \
        -rowindent [dict get $ex rowindent]]

    # -font / -boldfont were accepted and never applied until 0.3. They now
    # go to table::draw as -fontreg/-fontbold; empty still means the face
    # set loaded by fonts::init.
    if {$opts(-font)     ne ""} { lappend drawArgs -fontreg  $opts(-font) }
    if {$opts(-boldfont) ne ""} { lappend drawArgs -fontbold $opts(-boldfont) }

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

# Tk font spec -> keyword for table::draw (reg|bold|italic|bolditalic|mono).
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
