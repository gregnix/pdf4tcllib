# pdf4tcltext -- Tk Text-Widget Export nach PDF
#
# Exportiert Tk text-Widgets mit vollstaendiger Tag-Struktur
# (Bold, Italic, Farben, Einrueckung) als formatiertes PDF.
# Basiert auf $t dump -all.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Verwendung:
#   package require pdf4tcltext
#   pdf4tcltext::render $pdf $tw $x $y ...
#
# Abhaengigkeiten:
#   pdf4tcllib 0.2+, pdf4tcl 0.9.4.25+, Tk

package require pdf4tcllib 0.2

package provide pdf4tcltext 0.1

# ============================================================
# pdf4tcllib::textwidget -- Tk Text-Widget -> PDF
# Basiert auf $t dump -all -- liest komplette Tag-Struktur.
# ============================================================

namespace eval ::pdf4tcllib::textwidget {}

proc ::pdf4tcllib::textwidget::render {pdf tw x y args} {
    array set opts {
        -maxwidth    480  -fontsize    10  -fontfamily  Helvetica
        -linespacing 2    -skipelided  1   -skipinternal 1
        -ctx         {}   -yvar        {}
    }
    array set opts $args
    set orient 1
    if {$opts(-ctx) ne {}} { catch {set orient [dict get $opts(-ctx) orient]} }

    set tagCfg      [_readAllTagConfigs $tw]
    set tagPriority [_getTagPriority $tw]
    set dumpData    [$tw dump -all 1.0 end]

    set tagStack {}
    set curY     $y
    set lineBuffer {}
    set paraSpacingBefore 0

    set defaultStyle [dict create \
        font $opts(-fontfamily) fontsize $opts(-fontsize) \
        fg {0 0 0} bg {} underline 0 overstrike 0 elide 0 \
        lmargin1 0 lmargin2 0 spacing1 0 spacing3 0 justify left]

    foreach {key val idx} $dumpData {
        switch -- $key {
            "tagon" {
                if {$opts(-skipinternal) && $val in {sel insert}} continue
                lappend tagStack $val
            }
            "tagoff" {
                set pos [lsearch -exact $tagStack $val]
                if {$pos >= 0} { set tagStack [lreplace $tagStack $pos $pos] }
            }
            "text" {
                set style [_resolveStyle $tagCfg $tagStack $tagPriority \
                    $defaultStyle $opts(-fontfamily) $opts(-fontsize)]
                if {$opts(-skipelided) && [dict get $style elide]} continue

                set parts [split $val "\n"]
                foreach part [lrange $parts 0 end-1] {
                    if {$part ne ""} { lappend lineBuffer [list $part $style] }
                    set curY [_flushLine $pdf $lineBuffer $x \
                        $opts(-maxwidth) $curY $orient $opts(-linespacing) \
                        $paraSpacingBefore]
                    set lineBuffer {}
                    set paraSpacingBefore [dict get $style spacing3]
                }
                if {[lindex $parts end] ne ""} {
                    lappend lineBuffer [list [lindex $parts end] $style]
                }
            }
            "window" {
                set style [_resolveStyle $tagCfg $tagStack $tagPriority \
                    $defaultStyle $opts(-fontfamily) $opts(-fontsize)]
                lappend lineBuffer [list "\[Widget\]" $style]
            }
            "image" {
                set style [_resolveStyle $tagCfg $tagStack $tagPriority \
                    $defaultStyle $opts(-fontfamily) $opts(-fontsize)]
                lappend lineBuffer [list "\[Bild: $val\]" $style]
            }
        }
    }
    if {[llength $lineBuffer] > 0} {
        set curY [_flushLine $pdf $lineBuffer $x $opts(-maxwidth) $curY \
            $orient $opts(-linespacing) $paraSpacingBefore]
    }

    if {$opts(-yvar) ne {}} { upvar 1 $opts(-yvar) yret; set yret $curY }
    return $curY
}

proc ::pdf4tcllib::textwidget::_readAllTagConfigs {tw} {
    set result {}
    foreach tag [$tw tag names] {
        set cfg {}
        foreach opt {-font -foreground -background -underline -overstrike
                     -elide -lmargin1 -lmargin2 -spacing1 -spacing3 -justify} {
            set val ""
            catch { set val [$tw tag cget $tag $opt] }
            if {$val ne ""} { dict set cfg $opt $val }
        }
        dict set result $tag $cfg
    }
    return $result
}

proc ::pdf4tcllib::textwidget::_getTagPriority {tw} {
    set result {}; set prio 0
    foreach tag [$tw tag names] { dict set result $tag $prio; incr prio }
    return $result
}

proc ::pdf4tcllib::textwidget::_resolveStyle {tagCfg tagStack tagPriority \
                                               defaultStyle defFamily defSize} {
    set sorted [lsort -command [list ::pdf4tcllib::textwidget::_cmpPrio \
        $tagPriority] $tagStack]
    set style $defaultStyle
    foreach tag $sorted {
        if {![dict exists $tagCfg $tag]} continue
        set cfg [dict get $tagCfg $tag]
        if {[dict exists $cfg -font] && [dict get $cfg -font] ne ""} {
            lassign [_parseFont [dict get $cfg -font] $defFamily $defSize] \
                fam sz bold ital
            dict set style font     [_tclFontToPdf $fam $bold $ital]
            dict set style fontsize $sz
        }
        if {[dict exists $cfg -foreground] && [dict get $cfg -foreground] ne ""} {
            dict set style fg [_tkColorToRGB [dict get $cfg -foreground]]
        }
        if {[dict exists $cfg -background] && [dict get $cfg -background] ne ""} {
            dict set style bg [_tkColorToRGB [dict get $cfg -background]]
        }
        foreach {opt key} {-underline underline -overstrike overstrike -elide elide} {
            if {[dict exists $cfg $opt] && [dict get $cfg $opt] ne ""} {
                dict set style $key [dict get $cfg $opt]
            }
        }
        foreach {opt key} {-lmargin1 lmargin1 -spacing1 spacing1 -spacing3 spacing3} {
            if {[dict exists $cfg $opt] && [dict get $cfg $opt] ne ""} {
                set v [dict get $cfg $opt]
                if {[string is integer $v]} { dict set style $key [expr {$v*0.75}] }
            }
        }
        if {[dict exists $cfg -justify] && [dict get $cfg -justify] ne ""} {
            dict set style justify [dict get $cfg -justify]
        }
    }
    return $style
}

proc ::pdf4tcllib::textwidget::_cmpPrio {tagPrio a b} {
    set pa 0; catch {set pa [dict get $tagPrio $a]}
    set pb 0; catch {set pb [dict get $tagPrio $b]}
    return [expr {$pa - $pb}]
}

proc ::pdf4tcllib::textwidget::_flushLine {pdf lineBuffer x maxW curY \
                                            orient ls spacingBefore} {
    set lineH 12
    set lmargin 0
    foreach seg $lineBuffer {
        lassign $seg text style
        set fs [dict get $style fontsize]
        if {$fs > $lineH} { set lineH $fs }
        set lm [dict get $style lmargin1]
        if {$lm > $lmargin} { set lmargin $lm }
    }
    set lineH [expr {$lineH * 1.3 + $ls}]

    if {$spacingBefore > 0} {
        if {$orient} {set curY [expr {$curY+$spacingBefore}]} \
        else         {set curY [expr {$curY-$spacingBefore}]}
    }
    if {[llength $lineBuffer] == 0} {
        if {$orient} {return [expr {$curY+$lineH*0.5}]} \
        else         {return [expr {$curY-$lineH*0.5}]}
    }

    set baseline [expr {$orient ? $curY+$lineH-3 : $curY-3}]
    set cx [expr {$x + $lmargin}]

    # Hintergründe
    set cx0 $cx
    foreach seg $lineBuffer {
        lassign $seg text style
        set fs [dict get $style fontsize]; set fn [dict get $style font]
        set bg [dict get $style bg]
        $pdf setFont $fs $fn
        set w 0; catch {set w [$pdf getStringWidth $text]}
        if {$bg ne {}} {
            $pdf setFillColor {*}$bg
            if {$orient} { $pdf rectangle $cx0 $curY $w $lineH -filled 1 -stroke 0 } \
            else         { $pdf rectangle $cx0 [expr {$curY-$lineH}] $w $lineH -filled 1 -stroke 0 }
            $pdf setFillColor 0 0 0
        }
        set cx0 [expr {$cx0+$w}]
    }

    # Text
    set cx [expr {$x + $lmargin}]
    foreach seg $lineBuffer {
        lassign $seg text style
        set fs [dict get $style fontsize]; set fn [dict get $style font]
        set fg [dict get $style fg]
        set ul [dict get $style underline]; set os [dict get $style overstrike]
        $pdf setFont $fs $fn; $pdf setFillColor {*}$fg
        catch {set text [::pdf4tcllib::unicode::sanitize $text]}
        set w 0; catch {set w [$pdf getStringWidth $text]}
        $pdf text $text -x $cx -y $baseline
        if {$ul} {
            $pdf setStrokeColor {*}$fg; $pdf setLineWidth 0.5
            set uly [expr {$orient ? $baseline+1.5 : $baseline-1.5}]
            $pdf line $cx $uly [expr {$cx+$w}] $uly
        }
        if {$os} {
            $pdf setStrokeColor {*}$fg; $pdf setLineWidth 0.5
            set osy [expr {$orient ? $baseline-$fs*0.35 : $baseline+$fs*0.35}]
            $pdf line $cx $osy [expr {$cx+$w}] $osy
        }
        $pdf setFillColor 0 0 0
        set cx [expr {$cx+$w}]
    }

    if {$orient} {return [expr {$curY+$lineH}]} else {return [expr {$curY-$lineH}]}
}

proc ::pdf4tcllib::textwidget::_parseFont {fontSpec defFamily defSize} {
    set family $defFamily; set size $defSize; set bold 0; set italic 0
    if {![catch {font configure $fontSpec -family} fam]} {
        set family $fam
        catch {set size [font configure $fontSpec -size]}
        catch {if {[font configure $fontSpec -weight] eq "bold"} {set bold 1}}
        catch {if {[font configure $fontSpec -slant]  eq "italic"} {set italic 1}}
        return [list $family $size $bold $italic]
    }
    if {[string match "-*" [lindex $fontSpec 0]]} {
        catch {set family [dict get $fontSpec -family]}
        catch {set size   [dict get $fontSpec -size]}
        catch {if {[dict get $fontSpec -weight] eq "bold"}   {set bold 1}}
        catch {if {[dict get $fontSpec -slant]  eq "italic"} {set italic 1}}
        return [list $family $size $bold $italic]
    }
    if {[llength $fontSpec] >= 1} {set family [lindex $fontSpec 0]}
    if {[llength $fontSpec] >= 2} {
        set s [lindex $fontSpec 1]
        if {[string is integer $s]} {set size $s}
    }
    set styles [lrange $fontSpec 2 end]
    if {"bold" in $styles}               {set bold 1}
    if {"italic" in $styles || "oblique" in $styles} {set italic 1}
    return [list $family [expr {abs($size)}] $bold $italic]
}

proc ::pdf4tcllib::textwidget::_tclFontToPdf {family bold italic} {
    set isCourier [expr {
        [string match -nocase "courier*"    $family] ||
        [string match -nocase "*mono*"      $family] ||
        [string match -nocase "consolas"    $family] ||
        [string match -nocase "lucida*console*" $family]
    }]
    set isTimes [expr {
        [string match -nocase "times*"  $family] ||
        [string match -nocase "georgia" $family] ||
        $family eq "serif"
    }]
    if {$isCourier} {
        if {$bold && $italic} {return Courier-BoldOblique}
        if {$bold}            {return Courier-Bold}
        if {$italic}          {return Courier-Oblique}
        return Courier
    }
    if {$isTimes} {
        if {$bold && $italic} {return Times-BoldItalic}
        if {$bold}            {return Times-Bold}
        if {$italic}          {return Times-Italic}
        return Times-Roman
    }
    if {$bold && $italic} {return Helvetica-BoldOblique}
    if {$bold}            {return Helvetica-Bold}
    if {$italic}          {return Helvetica-Oblique}
    return Helvetica
}

proc ::pdf4tcllib::textwidget::_tkColorToRGB {color} {
    if {[regexp {^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$} \
            $color -> rh gh bh]} {
        return [list [expr {"0x$rh"/255.0}] [expr {"0x$gh"/255.0}] \
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

# ============================================================
# Ende pdf4tcllib::textwidget
# ============================================================

# Convenience-Alias: pdf4tcltext::render statt pdf4tcllib::textwidget::render
namespace eval ::pdf4tcltext {
    namespace import ::pdf4tcllib::textwidget::render
}
