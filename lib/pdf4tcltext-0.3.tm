# pdf4tcltext -- export a Tk text widget to PDF
#
# Exports a Tk text widget with its full tag structure -- bold, italic,
# colours, indentation -- as formatted PDF. Built on `$t dump -all`.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Usage:
#   package require pdf4tcltext
#   pdf4tcltext::render $pdf $tw $x $y ...
#
# Requires:
#   pdf4tcllib 0.2+, pdf4tcl 0.9.4.25+, Tk

package require pdf4tcllib 0.2

package provide pdf4tcltext 0.3

# ============================================================
# pdf4tcllib::textwidget -- Tk Text-Widget -> PDF
# Built on `$t dump -all` -- reads the complete tag structure.
# ============================================================

namespace eval ::pdf4tcllib::textwidget {
    # OHNE Exportmuster importiert "namespace import" nichts -- und zwar
    # ohne Fehler. Der Alias ::pdf4tcltext::render am Dateiende entstand
    # deshalb bis 0.2 gar nicht; wer der Doku folgte, bekam "invalid
    # command name". Gefunden von einer App, die das Modul benutzt.
    namespace export render
}

# Rejects an option the caller made up. Without this, `array set opts $args`
# accepts every key: a typo, a renamed option or an option this version does
# not implement is silently stored and never read. Measured 2026-08-15:
# `-quatsch 1` went through pdf4tcltable::render without a word.
proc ::pdf4tcllib::textwidget::_checkOpts {who defaults args_} {
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

proc ::pdf4tcllib::textwidget::render {pdf tw x y args} {
    array set opts {
        -maxwidth    480  -fontsize    10  -fontfamily  Helvetica
        -linespacing 2    -skipelided  1   -skipinternal 1
        -ctx         {}   -yvar        {}
    }
    _checkOpts ::pdf4tcllib::textwidget::render [array get opts] $args
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
        lmargin1 0 lmargin2 0 spacing1 0 spacing3 0 justify left offset 0]

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
                     -elide -lmargin1 -lmargin2 -spacing1 -spacing3 -justify
                     -offset} {
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
        # -offset ist wie -lmargin1 eine Pixelangabe des Widgets und
        # wird mit demselben Faktor in Punkt umgerechnet. Negativ heisst
        # tiefgestellt, positiv hochgestellt -- so wie bei Tk.
        foreach {opt key} {-lmargin1 lmargin1 -spacing1 spacing1 \
                           -spacing3 spacing3 -offset offset} {
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

    # Umbruch. Bis 0.2 bekam _flushLine maxW als Parameter und las ihn
    # NIE: eine Zeile des Widgets wurde eine PDF-Zeile, wie lang sie auch
    # war. Gemessen mit -maxwidth 200 und einem Absatz von 200 Zeichen:
    # EINE Zeile von 987 pt auf einem Blatt von 595 pt -- der Text lief
    # rechts hinaus, ohne Meldung, und keins der Pruefwerkzeuge sah es
    # (geometry-check schaut nicht auf Text, layout-check liest ueber
    # pdftotext, und pdftotext laesst weg, was neben dem Blatt liegt).
    foreach zeile [_splitToLines $pdf $lineBuffer $maxW $lmargin] {
        set curY [_drawLine $pdf $zeile $x $lmargin $lineH $curY $orient \
                $maxW]
    }
    return $curY
}

# Einen Zeilenpuffer auf die verfuegbare Breite aufteilen.
#
# Gemessen wird je Abschnitt mit DESSEN Schrift, denn ein Wort in fett
# ist breiter als dasselbe Wort mager -- eine Rechnung mit einer
# einzigen Schrift braeche an der falschen Stelle.
#
# Ein Wort, das allein schon breiter ist als der Platz, wird trotzdem
# gesetzt: abschneiden waere stiller Verlust, und eine Endlosschleife
# waere schlimmer als eine zu breite Zeile.
proc ::pdf4tcllib::textwidget::_splitToLines {pdf lineBuffer maxW lmargin} {
    if {$maxW <= 0 || [llength $lineBuffer] == 0} {
        return [list $lineBuffer]
    }
    set zeilen {}
    set aktuell {}
    set breite $lmargin
    foreach seg $lineBuffer {
        lassign $seg text style
        catch {$pdf setFont [dict get $style fontsize] [dict get $style font]}
        set puffer ""
        # Wort samt dem Leerraum dahinter -- so bleibt der Abstand am
        # Wort haengen und geht beim Umbruch mit ihm verloren.
        foreach wort [regexp -all -inline {\S+\s*|\s+} $text] {
            set ww 0
            catch {set ww [$pdf getStringWidth $wort]}
            if {$breite + $ww > $maxW && ($breite > $lmargin || $puffer ne "")} {
                if {$puffer ne ""} {
                    lappend aktuell [list [string trimright $puffer] $style]
                }
                lappend zeilen $aktuell
                set aktuell {}
                set puffer ""
                set breite $lmargin
                set wort [string trimleft $wort]
                if {$wort eq ""} continue
                set ww 0
                catch {set ww [$pdf getStringWidth $wort]}
            }
            append puffer $wort
            set breite [expr {$breite + $ww}]
        }
        if {$puffer ne ""} { lappend aktuell [list $puffer $style] }
    }
    if {[llength $aktuell]} { lappend zeilen $aktuell }
    if {![llength $zeilen]} { set zeilen [list $lineBuffer] }
    return $zeilen
}

# Eine fertige Zeile zeichnen. Der Rumpf stand bis 0.2 in _flushLine;
# herausgeloest, damit _flushLine ihn mehrfach rufen kann.
# Wie weit die Zeile nach rechts rueckt, damit sie zentriert oder
# rechtsbuendig steht. 0 fuer linksbuendig -- und fuer alles andere,
# solange keine Breite bekannt ist.
#
# Bis 0.2 war -justify "not implemented": center und right wirkten im
# Widget und verschwanden im PDF, ohne ein Wort. Eine Anwendung bot die
# Auswahl in ihrer Werkzeugleiste an und musste sie beschriften mit
# "nur Ansicht" -- das war der Anlass.
#
# Die Ausrichtung der ERSTEN Abschnitts der Zeile gilt fuer die ganze
# Zeile. Tk kennt -justify nur je Zeile, nicht je Zeichen; eine Zeile,
# deren Abschnitte verschieden ausgerichtet sein wollen, hat auf dem
# Bildschirm dasselbe Problem und loest es genauso.
proc ::pdf4tcllib::textwidget::_justifyOffset {pdf lineBuffer lmargin maxW} {
    if {$maxW <= 0 || ![llength $lineBuffer]} { return 0 }
    set just left
    catch {set just [dict get [lindex $lineBuffer 0 1] justify]}
    if {$just eq "left" || $just eq ""} { return 0 }

    set breite 0
    foreach seg $lineBuffer {
        lassign $seg text style
        catch {$pdf setFont [dict get $style fontsize] [dict get $style font]}
        set w 0
        catch {set w [$pdf getStringWidth $text]}
        set breite [expr {$breite + $w}]
    }
    set platz [expr {$maxW - $lmargin}]
    set rest [expr {$platz - $breite}]
    # Eine Zeile, die ohnehin nicht passt, wird nicht auch noch nach
    # links geschoben.
    if {$rest <= 0} { return 0 }
    if {$just eq "center"} { return [expr {$rest / 2.0}] }
    if {$just eq "right"}  { return $rest }
    return 0
}

proc ::pdf4tcllib::textwidget::_drawLine {pdf lineBuffer x lmargin lineH \
                                          curY orient {maxW 0}} {
    set baseline [expr {$orient ? $curY+$lineH-3 : $curY-3}]
    set cx [expr {$x + $lmargin + [_justifyOffset $pdf $lineBuffer $lmargin \
            $maxW]}]

    # Backgrounds
    #
    # Hintergrundfarben, Unterstreichungen und Durchstreichungen sind
    # Auszeichnung, kein Inhalt: sie tragen keinen Text, den ein
    # Vorleseprogramm ausgeben koennte. Ohne die Artefakt-Klammer zaehlt
    # jeder farbige Kasten und jeder Strich als ungetaggt -- gemessen an
    # einem Widget mit vier Auszeichnungen: 8 offene Zeichenbefehle.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
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
    ::pdf4tcllib::tag::artifactEnd $pdf

    # Text
    #
    # Eine Zeile ist ein Absatz im Sinne des Baums; die einzelnen
    # Abschnitte darin sind Span, weil sie sich nur in der Auszeichnung
    # unterscheiden, nicht in der Rolle.
    ::pdf4tcllib::tag::begin $pdf P
    set cx [expr {$x + $lmargin + [_justifyOffset $pdf $lineBuffer $lmargin \
            $maxW]}]
    foreach seg $lineBuffer {
        lassign $seg text style
        set fs [dict get $style fontsize]; set fn [dict get $style font]
        set fg [dict get $style fg]
        set ul [dict get $style underline]; set os [dict get $style overstrike]
        $pdf setFont $fs $fn; $pdf setFillColor {*}$fg
        catch {set text [::pdf4tcllib::unicode::sanitize $text]}
        set w 0; catch {set w [$pdf getStringWidth $text]}
        # Hoch- und Tiefstellung. Bis hierher war -offset "not
        # implemented": ein Fussnotenzeichen stand auf der Grundlinie
        # wie jeder andere Buchstabe. Der Wert verschiebt die
        # Grundlinie dieses Abschnitts, nicht der Zeile -- die
        # Zeilenhoehe bleibt, wie Tk es auch haelt. Wer kleiner setzen
        # will, gibt dem Tag zusaetzlich eine kleinere -font; das
        # Modul erfindet keine Schriftgroesse dazu.
        set off 0
        catch {set off [dict get $style offset]}
        set bl [expr {$orient ? $baseline-$off : $baseline+$off}]
        ::pdf4tcllib::tag::begin $pdf Span
        $pdf text $text -x $cx -y $bl
        ::pdf4tcllib::tag::end $pdf
        # Die Striche gehoeren zur Auszeichnung, nicht zum Text.
        ::pdf4tcllib::tag::artifact $pdf -type Layout
        if {$ul} {
            $pdf setStrokeColor {*}$fg; $pdf setLineWidth 0.5
            set uly [expr {$orient ? $bl+1.5 : $bl-1.5}]
            $pdf line $cx $uly [expr {$cx+$w}] $uly
        }
        if {$os} {
            $pdf setStrokeColor {*}$fg; $pdf setLineWidth 0.5
            set osy [expr {$orient ? $bl-$fs*0.35 : $bl+$fs*0.35}]
            $pdf line $cx $osy [expr {$cx+$w}] $osy
        }
        ::pdf4tcllib::tag::artifactEnd $pdf
        $pdf setFillColor 0 0 0
        set cx [expr {$cx+$w}]
    }
    ::pdf4tcllib::tag::end $pdf

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

# Eine Schrift, die der Aufrufer unter DIESEM Familiennamen geladen hat,
# zaehlt vor der Standardweiche.
#
# Bis 0.2 kannte _tclFontToPdf nur die 14 Standardschriften. Wer
# fonts::init laufen liess und im Widget "DejaVu Sans" auszeichnete,
# bekam im PDF Helvetica -- also gerade die Schrift ohne Glyphen jenseits
# Latin-1, und ohne ein Wort dazu. Dieselbe Ueberlegung wie in
# pdf4tcl::FindFontByFamily: erst nach einer Schrift dieses Namens
# suchen, dann raten.
#
# Rueckgabe ist der PDF-Fontname oder der leere String.
proc ::pdf4tcllib::textwidget::_loadedFontFor {family bold italic} {
    if {$family eq ""} { return "" }
    set alle {}
    catch {set alle [::pdf4tcl::getFonts]}
    if {![llength $alle]} { return "" }
    # Von der genauesten Schreibweise zur allgemeinsten. -Oblique neben
    # -Italic, weil beide Schreibweisen im Umlauf sind.
    set kandidaten {}
    if {$bold && $italic} {
        lappend kandidaten "$family-BoldItalic" "$family-BoldOblique"
    } elseif {$bold} {
        lappend kandidaten "$family-Bold"
    } elseif {$italic} {
        lappend kandidaten "$family-Italic" "$family-Oblique"
    }
    lappend kandidaten $family
    foreach k $kandidaten {
        if {$k in $alle} { return $k }
    }
    return ""
}

proc ::pdf4tcllib::textwidget::_tclFontToPdf {family bold italic} {
    set geladen [_loadedFontFor $family $bold $italic]
    if {$geladen ne ""} { return $geladen }
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
