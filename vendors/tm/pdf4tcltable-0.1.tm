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
#   pdf4tcllib 0.2+, pdf4tcl 0.9.4.25+, tablelist_tile

package require pdf4tcllib 0.2

package provide pdf4tcltable 0.1

# ============================================================
# pdf4tcllib::tablelist -- Tablelist-Widget -> PDF
# Csaba Nemethi tablelist (package tablelist_tile) -> PDF-Tabelle.
# Kein eingebauter Export in tablelist vorhanden (dumptostring
# ist internes Save/Restore-Format, kein CSV/HTML).
# ============================================================

namespace eval ::pdf4tcllib::tablelist {}

proc ::pdf4tcllib::tablelist::render {pdf tbl x y args} {
    # Exportiert tablelist-Widget als PDF-Tabelle.
    # pdf, tbl, x, y -- Pflicht
    # Optionen: siehe Manual pdf4tcllib-tablelist.md
    array set opts {
        -maxwidth  480  -fontsize  9   -rowheight 0
        -zebra     1    -border    1   -tree      1
        -indentW   12   -formatted 1   -yvar      {}
        -ctx       {}   -headerbg  {}  -headerfg  {}
    }
    array set opts $args
    set orient 1
    if {$opts(-ctx) ne {}} { catch {set orient [dict get $opts(-ctx) orient]} }
    set fs $opts(-fontsize)
    set rh $opts(-rowheight)
    if {$rh <= 0} { set rh [expr {int($fs * 1.8)}] }
    set pad 3

    # Spalten einlesen
    set ncols [$tbl columncount]
    set visCols {}; set colTitles {}; set colAligns {}; set colWidths {}
    for {set c 0} {$c < $ncols} {incr c} {
        set hide 0; catch {set hide [$tbl columncget $c -hide]}
        if {$hide} continue
        lappend visCols $c
        set title ""; catch {set title [$tbl columncget $c -title]}
        set align left; catch {set align [$tbl columncget $c -align]}
        set wch 5; catch {
            set wch [$tbl columncget $c -width]
            if {$wch < 0} {set wch [expr {-$wch}]}
            if {$wch == 0} {set wch 5}
        }
        lappend colTitles $title; lappend colAligns $align
        lappend colWidths $wch
    }
    if {[llength $visCols] == 0} { return $y }

    # Breiten skalieren
    set totalCh 0; foreach w $colWidths {incr totalCh $w}
    set pdfColW {}; set totalW 0
    foreach w $colWidths {
        set pw [expr {max(18, int($opts(-maxwidth) * $w / double($totalCh)))}]
        lappend pdfColW $pw; incr totalW $pw
    }

    # Zebrafarbe aus Widget
    set zebraColor {}
    if {$opts(-zebra)} {
        catch {
            set zc [$tbl cget -stripebackground]
            if {$zc ne ""} {set zebraColor [_tkColorToRGB $zc]}
        }
        if {$zebraColor eq {}} {set zebraColor {0.96 0.96 0.96}}
    }

    set curY $y

    # Header
    set hbg {0.82 0.86 0.94}
    if {$opts(-headerbg) ne {}} {
        set hbg $opts(-headerbg)
    } else {
        catch {
            set lb [$tbl columncget [lindex $visCols 0] -labelbackground]
            if {$lb ne ""} {set hbg [_tkColorToRGB $lb]}
        }
    }
    set hfg {0 0 0}
    if {$opts(-headerfg) ne {}} {
        set hfg $opts(-headerfg)
    } else {
        catch {
            set lf [$tbl columncget [lindex $visCols 0] -labelforeground]
            if {$lf ne ""} {set hfg [_tkColorToRGB $lf]}
        }
    }

    $pdf setFillColor {*}$hbg
    $pdf rectangle $x $curY $totalW $rh -filled 1 -stroke 0
    $pdf setFillColor 0 0 0
    if {$opts(-border)} {
        $pdf setStrokeColor 0.45 0.45 0.45
        $pdf setLineWidth 0.6
        $pdf rectangle $x $curY $totalW $rh
    }

    $pdf setFont $fs Helvetica-Bold
    $pdf setFillColor {*}$hfg
    set cx $x; set ci 0
    foreach title $colTitles align $colAligns pw $pdfColW {
        set bl [expr {$curY + $rh - $pad}]
        set t [_truncate $pdf $title [expr {$pw - 2*$pad}]]
        switch -- $align {
            right  {$pdf text $t -x [expr {$cx+$pw-$pad}] -y $bl -align right}
            center {$pdf text $t -x [expr {$cx+$pw/2}] -y $bl -align center}
            default {$pdf text $t -x [expr {$cx+$pad}] -y $bl}
        }
        if {$opts(-border) && $ci < [llength $visCols]-1} {
            $pdf setStrokeColor 0.6 0.6 0.6; $pdf setLineWidth 0.3
            $pdf line [expr {$cx+$pw}] $curY [expr {$cx+$pw}] \
                      [expr {$curY+$rh}]
        }
        set cx [expr {$cx+$pw}]; incr ci
    }
    $pdf setFillColor 0 0 0

    if {$orient} {set curY [expr {$curY+$rh}]} else {set curY [expr {$curY-$rh}]}

    # Daten
    set allRows {}
    if {$opts(-formatted)} {catch {set allRows [$tbl getformatted 0 end]}}
    if {[llength $allRows] == 0} {catch {set allRows [$tbl get 0 end]}}

    set nrows [$tbl size]
    $pdf setFont $fs Helvetica

    for {set r 0} {$r < $nrows} {incr r} {
        set hide 0; catch {set hide [$tbl rowcget $r -hide]}
        if {$hide} continue

        set rowBg {}; catch {set rowBg [$tbl rowcget $r -background]}
        if {$rowBg ne {} && $rowBg ne ""} {
            $pdf setFillColor {*}[_tkColorToRGB $rowBg]
            $pdf rectangle $x $curY $totalW $rh -filled 1 -stroke 0
            $pdf setFillColor 0 0 0
        } elseif {$opts(-zebra) && $r%2==1 && $zebraColor ne {}} {
            $pdf setFillColor {*}$zebraColor
            $pdf rectangle $x $curY $totalW $rh -filled 1 -stroke 0
            $pdf setFillColor 0 0 0
        }
        if {$opts(-border)} {
            $pdf setStrokeColor 0.78 0.78 0.78; $pdf setLineWidth 0.3
            $pdf line $x $curY [expr {$x+$totalW}] $curY
        }

        set rowFg {0 0 0}
        catch {set f [$tbl rowcget $r -foreground]
               if {$f ne ""} {set rowFg [_tkColorToRGB $f]}}
        set rowFont Helvetica
        catch {set rowFont [_tclFontToPdf [$tbl rowcget $r -font] $fs]}

        set indent 0
        if {$opts(-tree)} {
            catch {set indent [expr {max(0,[$tbl depth $r]-1) * $opts(-indentW)}]}
        }

        set rowData [lindex $allRows $r]
        set cx $x; set ci 0
        foreach c $visCols align $colAligns pw $pdfColW {
            set ct ""
            if {[llength $rowData] > $c} {set ct [lindex $rowData $c]}
            catch {set t2 [$tbl cellcget $r,$c -text]; if {$t2 ne ""} {set ct $t2}}

            set cf $rowFont
            catch {set f2 [$tbl cellcget $r,$c -font]
                   if {$f2 ne ""} {set cf [_tclFontToPdf $f2 $fs]}}

            set cellBg {}
            catch {set b [$tbl cellcget $r,$c -background]
                   if {$b ne "" && $b ne {}} {set cellBg [_tkColorToRGB $b]}}
            if {$cellBg ne {}} {
                $pdf setFillColor {*}$cellBg
                $pdf rectangle $cx $curY $pw $rh -filled 1 -stroke 0
                $pdf setFillColor 0 0 0
            }

            set cellFg $rowFg
            catch {set fg [$tbl cellcget $r,$c -foreground]
                   if {$fg ne "" && $fg ne {}} {set cellFg [_tkColorToRGB $fg]}}

            $pdf setFont $fs $cf
            $pdf setFillColor {*}$cellFg
            catch {set ct [::pdf4tcllib::unicode::sanitize $ct]}
            set xoff [expr {$ci==0 ? $indent : 0}]
            set ct [_truncate $pdf $ct [expr {$pw-2*$pad-$xoff}]]
            set bl [expr {$curY+$rh-$pad}]
            switch -- $align {
                right  {$pdf text $ct -x [expr {$cx+$pw-$pad}] -y $bl -align right}
                center {$pdf text $ct -x [expr {$cx+$pw/2}] -y $bl -align center}
                default {$pdf text $ct -x [expr {$cx+$pad+$xoff}] -y $bl}
            }
            $pdf setFillColor 0 0 0
            if {$opts(-border) && $ci < [llength $visCols]-1} {
                $pdf setStrokeColor 0.75 0.75 0.75; $pdf setLineWidth 0.3
                $pdf line [expr {$cx+$pw}] $curY [expr {$cx+$pw}] \
                          [expr {$curY+$rh}]
            }
            set cx [expr {$cx+$pw}]; incr ci
        }
        if {$orient} {set curY [expr {$curY+$rh}]} \
        else         {set curY [expr {$curY-$rh}]}
    }

    if {$opts(-border)} {
        $pdf setStrokeColor 0.45 0.45 0.45; $pdf setLineWidth 0.6
        $pdf line $x $curY [expr {$x+$totalW}] $curY
        set boxH [expr {$orient ? ($curY-$y) : ($y-$curY)}]
        $pdf rectangle $x $y $totalW $boxH
    }

    if {$opts(-yvar) ne {}} {upvar 1 $opts(-yvar) yret; set yret $curY}
    return $curY
}

proc ::pdf4tcllib::tablelist::renderRange {pdf tbl x y args} {
    # Wie render, aber nur Zeilen -firstrow bis -lastrow.
    # Fuer Seitenumbruch-Implementierungen.
    array set opts {
        -maxwidth  480  -fontsize  9   -rowheight 0
        -zebra     1    -border    1   -tree      1
        -indentW   12   -formatted 1   -firstrow  0
        -lastrow   -1   -yvar      {}  -ctx       {}
        -headerbg  {}   -headerfg  {}
    }
    array set opts $args
    set orient 1
    if {$opts(-ctx) ne {}} {catch {set orient [dict get $opts(-ctx) orient]}}
    set fs $opts(-fontsize)
    set rh $opts(-rowheight)
    if {$rh <= 0} {set rh [expr {int($fs * 1.8)}]}
    set pad 3

    set ncols [$tbl columncount]
    set visCols {}; set colTitles {}; set colAligns {}; set colWidths {}
    for {set c 0} {$c < $ncols} {incr c} {
        set hide 0; catch {set hide [$tbl columncget $c -hide]}
        if {$hide} continue
        lappend visCols $c
        set title ""; catch {set title [$tbl columncget $c -title]}
        set align left; catch {set align [$tbl columncget $c -align]}
        set wch 5; catch {
            set wch [$tbl columncget $c -width]
            if {$wch < 0} {set wch [expr {-$wch}]}
            if {$wch == 0} {set wch 5}
        }
        lappend colTitles $title; lappend colAligns $align; lappend colWidths $wch
    }
    if {[llength $visCols] == 0} {return $y}

    set totalCh 0; foreach w $colWidths {incr totalCh $w}
    set pdfColW {}; set totalW 0
    foreach w $colWidths {
        set pw [expr {max(18, int($opts(-maxwidth) * $w / double($totalCh)))}]
        lappend pdfColW $pw; incr totalW $pw
    }

    set zebraColor {}
    if {$opts(-zebra)} {
        catch {set zc [$tbl cget -stripebackground]
               if {$zc ne ""} {set zebraColor [_tkColorToRGB $zc]}}
        if {$zebraColor eq {}} {set zebraColor {0.96 0.96 0.96}}
    }

    set curY $y
    # Header
    set hbg {0.82 0.86 0.94}
    if {$opts(-headerbg) ne {}} {set hbg $opts(-headerbg)} else {
        catch {set lb [$tbl columncget [lindex $visCols 0] -labelbackground]
               if {$lb ne ""} {set hbg [_tkColorToRGB $lb]}}
    }
    $pdf setFillColor {*}$hbg
    $pdf rectangle $x $curY $totalW $rh -filled 1 -stroke 0
    $pdf setFillColor 0 0 0
    if {$opts(-border)} {
        $pdf setStrokeColor 0.45 0.45 0.45; $pdf setLineWidth 0.6
        $pdf rectangle $x $curY $totalW $rh
    }
    $pdf setFont $fs Helvetica-Bold
    set cx $x; set ci 0
    foreach title $colTitles align $colAligns pw $pdfColW {
        set bl [expr {$curY+$rh-$pad}]
        set t [_truncate $pdf $title [expr {$pw-2*$pad}]]
        switch -- $align {
            right  {$pdf text $t -x [expr {$cx+$pw-$pad}] -y $bl -align right}
            center {$pdf text $t -x [expr {$cx+$pw/2}] -y $bl -align center}
            default {$pdf text $t -x [expr {$cx+$pad}] -y $bl}
        }
        if {$opts(-border) && $ci < [llength $visCols]-1} {
            $pdf setStrokeColor 0.6 0.6 0.6; $pdf setLineWidth 0.3
            $pdf line [expr {$cx+$pw}] $curY [expr {$cx+$pw}] [expr {$curY+$rh}]
        }
        set cx [expr {$cx+$pw}]; incr ci
    }
    $pdf setFillColor 0 0 0
    if {$orient} {set curY [expr {$curY+$rh}]} else {set curY [expr {$curY-$rh}]}

    set allRows {}
    if {$opts(-formatted)} {catch {set allRows [$tbl getformatted 0 end]}}
    if {[llength $allRows] == 0} {catch {set allRows [$tbl get 0 end]}}

    set nrows [$tbl size]
    set lastrow $opts(-lastrow)
    if {$lastrow < 0 || $lastrow >= $nrows} {set lastrow [expr {$nrows-1}]}
    $pdf setFont $fs Helvetica

    for {set r $opts(-firstrow)} {$r <= $lastrow} {incr r} {
        set hide 0; catch {set hide [$tbl rowcget $r -hide]}
        if {$hide} continue

        set rowBg {}; catch {set rowBg [$tbl rowcget $r -background]}
        if {$rowBg ne {} && $rowBg ne ""} {
            $pdf setFillColor {*}[_tkColorToRGB $rowBg]
            $pdf rectangle $x $curY $totalW $rh -filled 1 -stroke 0
            $pdf setFillColor 0 0 0
        } elseif {$opts(-zebra) && $r%2==1 && $zebraColor ne {}} {
            $pdf setFillColor {*}$zebraColor
            $pdf rectangle $x $curY $totalW $rh -filled 1 -stroke 0
            $pdf setFillColor 0 0 0
        }
        if {$opts(-border)} {
            $pdf setStrokeColor 0.78 0.78 0.78; $pdf setLineWidth 0.3
            $pdf line $x $curY [expr {$x+$totalW}] $curY
        }

        set rowFg {0 0 0}
        catch {set f [$tbl rowcget $r -foreground]
               if {$f ne ""} {set rowFg [_tkColorToRGB $f]}}
        set rowFont Helvetica
        catch {set rowFont [_tclFontToPdf [$tbl rowcget $r -font] $fs]}

        set indent 0
        if {$opts(-tree)} {
            catch {set indent [expr {max(0,[$tbl depth $r]-1)*$opts(-indentW)}]}
        }

        set rowData [lindex $allRows $r]
        set cx $x; set ci 0
        foreach c $visCols align $colAligns pw $pdfColW {
            set ct ""
            if {[llength $rowData] > $c} {set ct [lindex $rowData $c]}
            catch {set t2 [$tbl cellcget $r,$c -text]; if {$t2 ne ""} {set ct $t2}}
            set cf $rowFont
            catch {set f2 [$tbl cellcget $r,$c -font]
                   if {$f2 ne ""} {set cf [_tclFontToPdf $f2 $fs]}}
            set cellBg {}
            catch {set b [$tbl cellcget $r,$c -background]
                   if {$b ne "" && $b ne {}} {set cellBg [_tkColorToRGB $b]}}
            if {$cellBg ne {}} {
                $pdf setFillColor {*}$cellBg
                $pdf rectangle $cx $curY $pw $rh -filled 1 -stroke 0
                $pdf setFillColor 0 0 0
            }
            set cellFg $rowFg
            catch {set fg [$tbl cellcget $r,$c -foreground]
                   if {$fg ne "" && $fg ne {}} {set cellFg [_tkColorToRGB $fg]}}
            $pdf setFont $fs $cf
            $pdf setFillColor {*}$cellFg
            catch {set ct [::pdf4tcllib::unicode::sanitize $ct]}
            set xoff [expr {$ci==0 ? $indent : 0}]
            set ct [_truncate $pdf $ct [expr {$pw-2*$pad-$xoff}]]
            set bl [expr {$curY+$rh-$pad}]
            switch -- $align {
                right  {$pdf text $ct -x [expr {$cx+$pw-$pad}] -y $bl -align right}
                center {$pdf text $ct -x [expr {$cx+$pw/2}] -y $bl -align center}
                default {$pdf text $ct -x [expr {$cx+$pad+$xoff}] -y $bl}
            }
            $pdf setFillColor 0 0 0
            if {$opts(-border) && $ci < [llength $visCols]-1} {
                $pdf setStrokeColor 0.75 0.75 0.75; $pdf setLineWidth 0.3
                $pdf line [expr {$cx+$pw}] $curY [expr {$cx+$pw}] \
                          [expr {$curY+$rh}]
            }
            set cx [expr {$cx+$pw}]; incr ci
        }
        if {$orient} {set curY [expr {$curY+$rh}]} \
        else         {set curY [expr {$curY-$rh}]}
    }

    if {$opts(-border)} {
        $pdf setStrokeColor 0.45 0.45 0.45; $pdf setLineWidth 0.6
        $pdf line $x $curY [expr {$x+$totalW}] $curY
        set boxH [expr {$orient ? ($curY-$y) : ($y-$curY)}]
        $pdf rectangle $x $y $totalW $boxH
    }

    if {$opts(-yvar) ne {}} {upvar 1 $opts(-yvar) yret; set yret $curY}
    return $curY
}

proc ::pdf4tcllib::tablelist::_truncate {pdf text maxW} {
    if {[catch {set w [$pdf getStringWidth $text]}]} {return $text}
    if {$w <= $maxW} {return $text}
    while {[string length $text] > 1} {
        set text [string range $text 0 end-1]
        if {![catch {set w [$pdf getStringWidth "${text}..."]}]} {
            if {$w <= $maxW} {return "${text}..."}
        }
    }
    return "..."
}

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

proc ::pdf4tcllib::tablelist::_tclFontToPdf {fontSpec fs} {
    set bold   [expr {[lsearch $fontSpec bold]   >= 0}]
    set italic [expr {[lsearch $fontSpec italic] >= 0 || \
                      [lsearch $fontSpec oblique] >= 0}]
    if {[lsearch -glob $fontSpec {Courier*}] >= 0 || \
        [lsearch -glob $fontSpec {courier*}] >= 0 || \
        [lsearch -glob $fontSpec {Mono*}]    >= 0} {
        if {$bold} {return Courier-Bold}
        return Courier
    }
    if {$bold && $italic} {return Helvetica-BoldOblique}
    if {$bold}            {return Helvetica-Bold}
    if {$italic}          {return Helvetica-Oblique}
    return Helvetica
}

# ============================================================
# Ende pdf4tcllib::tablelist
# ============================================================


# Convenience-Alias: pdf4tcltable::render statt pdf4tcllib::tablelist::render
namespace eval ::pdf4tcltable {
    namespace import ::pdf4tcllib::tablelist::render
    namespace import ::pdf4tcllib::tablelist::renderRange
}
