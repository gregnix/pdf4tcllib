# pdf4tclchart -- bar, line and pie charts
#
# Data-driven and Tk-free, in the manner of table::draw: the caller hands
# over labels and numbers, the module owns the geometry -- scale, axis,
# grid, where the bars sit. Built on drawing:: and the pdf4tcl primitives,
# so it needs no canvas and no image.
#
# What it deliberately is not: a plotting library. There are no logarithmic
# axes, no error bars, no second y axis, no regression lines. It draws the
# three shapes a report needs, and it draws them so the numbers can be read
# off the page.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Usage:
#   package require pdf4tclchart
#   ::pdf4tcllib::chart::bar $pdf $x $y $w $h {Jan 120 Feb 145 Mar 98}
#
# Requires: pdf4tcllib 0.6+, pdf4tcl 0.9.4.23+

package require pdf4tcllib 0.6

package provide pdf4tclchart 0.1

namespace eval ::pdf4tcllib::chart {
    namespace export bar line pie legend niceScale

    # A palette that survives being printed in grey: the six colours have
    # distinct lightness, not just distinct hue. A chart that only works in
    # colour is half a chart.
    variable PALETTE {
        {0.20 0.35 0.60}
        {0.85 0.55 0.15}
        {0.35 0.60 0.35}
        {0.65 0.25 0.35}
        {0.50 0.50 0.55}
        {0.15 0.55 0.65}
    }

    variable CFG
    array set CFG {
        -title      {}
        -titlesize  11
        -labelsize  8
        -valuesize  8
        -color      {}
        -colors     {}
        -grid       4
        -gridcolor  {0.85 0.85 0.85}
        -axiscolor  {0.35 0.35 0.35}
        -values     0
        -format     %g
        -min        {}
        -max        {}
        -baseline   0
        -alt        {}
        -legend     0
    }
}

# ---------------------------------------------------------------------------
# niceScale -- a maximum a reader can divide by eye
# ---------------------------------------------------------------------------
#
# 137 becomes 150, not 137. The axis of a report is read, not measured, and
# a grid line at 137 helps nobody. Returns {min max step}.
proc ::pdf4tcllib::chart::niceScale {min max {ticks 4}} {
    if {$max <= $min} { set max [expr {$min + 1.0}] }
    set span [expr {double($max - $min)}]
    set raw  [expr {$span / $ticks}]
    set mag  [expr {pow(10, floor(log10($raw)))}]
    set norm [expr {$raw / $mag}]
    if {$norm <= 1.0}      { set step [expr {1.0 * $mag}]
    } elseif {$norm <= 2.0} { set step [expr {2.0 * $mag}]
    } elseif {$norm <= 5.0} { set step [expr {5.0 * $mag}]
    } else                  { set step [expr {10.0 * $mag}] }
    set lo [expr {floor($min / $step) * $step}]
    set hi [expr {ceil($max / $step) * $step}]
    return [list $lo $hi $step]
}

# Normalise {label value label value ...} or {{label value} ...} into a
# list of pairs. Both forms turn up in calling code, and guessing wrong is
# the sort of thing that shows up as a chart with one bar.
proc ::pdf4tcllib::chart::_pairs {who data} {
    if {![llength $data]} {
        return -code error "$who: no data"
    }
    set flat 1
    foreach e $data {
        if {[llength $e] != 2} { set flat 1; break }
        set flat 0
    }
    if {!$flat} { return $data }
    if {[llength $data] % 2} {
        return -code error "$who: data must be label/value pairs or a list\
                of {label value}, got [llength $data] element(s)"
    }
    set out {}
    foreach {l v} $data { lappend out [list $l $v] }
    return $out
}

proc ::pdf4tcllib::chart::_opts {who args} {
    variable CFG
    array set o [array get CFG]
    if {[llength $args] % 2} {
        return -code error "$who: expected option/value pairs"
    }
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "$who: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    return [array get o]
}

proc ::pdf4tcllib::chart::_colorFor {opts idx} {
    variable PALETTE
    array set o $opts
    if {[llength $o(-colors)]} {
        return [lindex $o(-colors) [expr {$idx % [llength $o(-colors)]}]]
    }
    if {[llength $o(-color)]} { return $o(-color) }
    return [lindex $PALETTE [expr {$idx % [llength $PALETTE]}]]
}

# A chart is a figure. Tagged, it is one element with an alternate text --
# without that a reader announces a scattering of numbers and nothing else.
# The parts inside are decoration and are marked as artifacts.
proc ::pdf4tcllib::chart::_beginFigure {pdf opts} {
    array set o $opts
    set alt $o(-alt)
    if {$alt eq "" && $o(-title) ne ""} { set alt $o(-title) }
    if {[catch {::pdf4tcllib::tag::begin $pdf Figure -alt $alt}]} {
        catch {::pdf4tcllib::tag::begin $pdf Figure}
    }
}
proc ::pdf4tcllib::chart::_endFigure {pdf} {
    catch {::pdf4tcllib::tag::end $pdf}
}

# Title above the plot area. Returns the y where the plot starts.
proc ::pdf4tcllib::chart::_title {pdf x y w opts} {
    array set o $opts
    if {$o(-title) eq ""} { return $y }
    $pdf setFont $o(-titlesize) [::pdf4tcllib::_defaultFamily]
    $pdf setFillColor 0 0 0
    ::pdf4tcllib::unicode::safeText $pdf $o(-title) \
            -x [expr {$x + $w / 2.0}] -y [expr {$y + $o(-titlesize)}] -align center
    return [expr {$y + $o(-titlesize) * 1.8}]
}

# Grid lines and the value axis. Returns nothing; draws inside the plot box.
proc ::pdf4tcllib::chart::_grid {pdf px py pw ph lo hi step opts} {
    array set o $opts
    if {$o(-grid) <= 0} { return }
    lassign $o(-gridcolor) gr gg gb
    $pdf setFont $o(-labelsize) [::pdf4tcllib::_defaultFamily]
    for {set v $lo} {$v <= $hi + $step / 1000.0} {set v [expr {$v + $step}]} {
        set frac [expr {($v - $lo) / double($hi - $lo)}]
        set ly   [expr {$py + $ph - $frac * $ph}]
        $pdf setStrokeColor $gr $gg $gb
        $pdf setLineWidth 0.4
        $pdf line $px $ly [expr {$px + $pw}] $ly
        $pdf setFillColor 0.3 0.3 0.3
        ::pdf4tcllib::unicode::safeText $pdf [format $o(-format) $v] \
                -x [expr {$px - 4}] -y [expr {$ly + $o(-labelsize) * 0.35}] \
                -align right
    }
    lassign $o(-axiscolor) ar ag ab
    $pdf setStrokeColor $ar $ag $ab
    $pdf setLineWidth 0.8
    $pdf line $px [expr {$py + $ph}] [expr {$px + $pw}] [expr {$py + $ph}]
    $pdf line $px $py $px [expr {$py + $ph}]
    $pdf setFillColor 0 0 0
}

# The left margin the value labels need. Measured, not guessed: a chart
# whose axis labels stick out of the box is the usual way this goes wrong.
proc ::pdf4tcllib::chart::_axisWidth {pdf lo hi step opts} {
    array set o $opts
    $pdf setFont $o(-labelsize) [::pdf4tcllib::_defaultFamily]
    set wmax 0
    for {set v $lo} {$v <= $hi + $step / 1000.0} {set v [expr {$v + $step}]} {
        set w [$pdf getStringWidth [format $o(-format) $v]]
        if {$w > $wmax} { set wmax $w }
    }
    return [expr {$wmax + 8}]
}

# ---------------------------------------------------------------------------
# bar -- vertical bar chart
# ---------------------------------------------------------------------------
#
#   ::pdf4tcllib::chart::bar $pdf $x $y $w $h $data ?option value ...?
#
#   data   {label value label value ...} or {{label value} ...}
#
# Draws inside the box (x, y, w, h); y counts downwards like everywhere
# else in this library. Returns the y below the chart.
proc ::pdf4tcllib::chart::bar {pdf x y w h data args} {
    set opts [_opts "chart::bar" {*}$args]
    array set o $opts
    set pairs [_pairs "chart::bar" $data]

    set vals {}
    foreach p $pairs {
        lassign $p label v
        if {![string is double -strict $v]} {
            return -code error "chart::bar: value for \"$label\" is not a\
                    number: \"$v\""
        }
        lappend vals $v
    }
    set lo [expr {$o(-min) eq "" ? min(0, [tcl::mathfunc::min {*}$vals]) : $o(-min)}]
    set hi [expr {$o(-max) eq "" ? [tcl::mathfunc::max {*}$vals] : $o(-max)}]
    lassign [niceScale $lo $hi $o(-grid)] lo hi step

    _beginFigure $pdf $opts
    ::pdf4tcllib::tag::artifact $pdf -type Layout

    set top [_title $pdf $x $y $w $opts]
    set axisW  [_axisWidth $pdf $lo $hi $step $opts]
    set labelH [expr {$o(-labelsize) * 2.0}]
    set px [expr {$x + $axisW}]
    set py $top
    set pw [expr {$w - $axisW}]
    set ph [expr {$y + $h - $top - $labelH}]
    if {$ph <= 0 || $pw <= 0} {
        ::pdf4tcllib::tag::artifactEnd $pdf
        _endFigure $pdf
        return -code error "chart::bar: box too small -- [format %.1f $w] x\
                [format %.1f $h] pt leaves no room for axis and labels"
    }

    _grid $pdf $px $py $pw $ph $lo $hi $step $opts

    set n     [llength $pairs]
    set slot  [expr {$pw / double($n)}]
    set bw    [expr {$slot * 0.65}]
    set zeroY [expr {$py + $ph - (0.0 - $lo) / double($hi - $lo) * $ph}]

    set i 0
    foreach p $pairs {
        lassign $p label v
        set frac [expr {($v - $lo) / double($hi - $lo)}]
        set vy   [expr {$py + $ph - $frac * $ph}]
        set bx   [expr {$px + $i * $slot + ($slot - $bw) / 2.0}]
        set bh   [expr {$zeroY - $vy}]

        lassign [_colorFor $opts $i] r g b
        $pdf setFillColor $r $g $b
        if {$bh >= 0} {
            $pdf rectangle $bx $vy $bw $bh -filled 1
        } else {
            $pdf rectangle $bx $zeroY $bw [expr {-$bh}] -filled 1
        }

        $pdf setFillColor 0.2 0.2 0.2
        $pdf setFont $o(-labelsize) [::pdf4tcllib::_defaultFamily]
        ::pdf4tcllib::unicode::safeText $pdf $label \
                -x [expr {$bx + $bw / 2.0}] \
                -y [expr {$py + $ph + $o(-labelsize) * 1.3}] -align center
        if {$o(-values)} {
            $pdf setFont $o(-valuesize) [::pdf4tcllib::_defaultFamily]
            set ty [expr {$bh >= 0 ? $vy - 3 : $vy + $o(-valuesize) + 1}]
            ::pdf4tcllib::unicode::safeText $pdf [format $o(-format) $v] \
                    -x [expr {$bx + $bw / 2.0}] -y $ty -align center
        }
        incr i
    }
    $pdf setFillColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
    _endFigure $pdf
    return [expr {$y + $h}]
}

# ---------------------------------------------------------------------------
# line -- line chart, one or several series
# ---------------------------------------------------------------------------
#
#   data   one series as for bar, or several as
#          {{name {label value ...}} {name {label value ...}}}
#
# The x labels come from the first series; the others are drawn against the
# same positions.
proc ::pdf4tcllib::chart::line {pdf x y w h data args} {
    set opts [_opts "chart::line" {*}$args]
    array set o $opts

    # One series or several? A series is {name {data}}, a data point is
    # {label value} -- the difference is whether the second element is
    # itself a list of pairs.
    set series {}
    set multi 0
    foreach e $data {
        if {[llength $e] == 2 && [llength [lindex $e 1]] > 2} { set multi 1 }
    }
    if {$multi} {
        foreach e $data {
            lassign $e name pts
            lappend series [list $name [_pairs "chart::line" $pts]]
        }
    } else {
        set series [list [list "" [_pairs "chart::line" $data]]]
    }

    set vals {}
    foreach s $series {
        foreach p [lindex $s 1] {
            lassign $p label v
            if {![string is double -strict $v]} {
                return -code error "chart::line: value for \"$label\" is not\
                        a number: \"$v\""
            }
            lappend vals $v
        }
    }
    set lo [expr {$o(-min) eq "" ? min(0, [tcl::mathfunc::min {*}$vals]) : $o(-min)}]
    set hi [expr {$o(-max) eq "" ? [tcl::mathfunc::max {*}$vals] : $o(-max)}]
    lassign [niceScale $lo $hi $o(-grid)] lo hi step

    _beginFigure $pdf $opts
    ::pdf4tcllib::tag::artifact $pdf -type Layout

    set top    [_title $pdf $x $y $w $opts]
    set axisW  [_axisWidth $pdf $lo $hi $step $opts]
    set labelH [expr {$o(-labelsize) * 2.0}]
    set px [expr {$x + $axisW}]
    set py $top
    set pw [expr {$w - $axisW}]
    set ph [expr {$y + $h - $top - $labelH}]
    if {$ph <= 0 || $pw <= 0} {
        ::pdf4tcllib::tag::artifactEnd $pdf
        _endFigure $pdf
        return -code error "chart::line: box too small"
    }

    _grid $pdf $px $py $pw $ph $lo $hi $step $opts

    set n [llength [lindex $series 0 1]]
    set dx [expr {$n > 1 ? $pw / double($n - 1) : 0}]

    set si 0
    foreach s $series {
        lassign $s name pts
        lassign [_colorFor $opts $si] r g b
        $pdf setStrokeColor $r $g $b
        $pdf setLineWidth 1.4
        set i 0
        set prevX {}
        set prevY {}
        foreach p $pts {
            lassign $p label v
            set frac [expr {($v - $lo) / double($hi - $lo)}]
            set ptx  [expr {$px + $i * $dx}]
            set pty  [expr {$py + $ph - $frac * $ph}]
            if {$prevX ne ""} { $pdf line $prevX $prevY $ptx $pty }
            set prevX $ptx
            set prevY $pty
            incr i
        }
        # The points, so a single value is visible at all
        $pdf setFillColor $r $g $b
        set i 0
        foreach p $pts {
            lassign $p label v
            set frac [expr {($v - $lo) / double($hi - $lo)}]
            $pdf circle [expr {$px + $i * $dx}] \
                    [expr {$py + $ph - $frac * $ph}] 2 -filled 1
            incr i
        }
        incr si
    }

    # x labels from the first series
    $pdf setFillColor 0.2 0.2 0.2
    $pdf setFont $o(-labelsize) [::pdf4tcllib::_defaultFamily]
    set i 0
    foreach p [lindex $series 0 1] {
        lassign $p label v
        ::pdf4tcllib::unicode::safeText $pdf $label \
                -x [expr {$px + $i * $dx}] \
                -y [expr {$py + $ph + $o(-labelsize) * 1.3}] -align center
        incr i
    }
    $pdf setFillColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
    _endFigure $pdf
    return [expr {$y + $h}]
}

# ---------------------------------------------------------------------------
# pie -- pie chart
# ---------------------------------------------------------------------------
#
# Percentages are computed from the sum; a negative value is an error,
# because a negative slice of a whole means nothing.
proc ::pdf4tcllib::chart::pie {pdf x y w h data args} {
    set opts [_opts "chart::pie" {*}$args]
    array set o $opts
    set pairs [_pairs "chart::pie" $data]

    set total 0.0
    foreach p $pairs {
        lassign $p label v
        if {![string is double -strict $v]} {
            return -code error "chart::pie: value for \"$label\" is not a\
                    number: \"$v\""
        }
        if {$v < 0} {
            return -code error "chart::pie: negative value for \"$label\" --\
                    a slice of a whole cannot be negative"
        }
        set total [expr {$total + $v}]
    }
    if {$total <= 0} {
        return -code error "chart::pie: the values add up to 0"
    }

    _beginFigure $pdf $opts
    ::pdf4tcllib::tag::artifact $pdf -type Layout

    set top [_title $pdf $x $y $w $opts]
    set avail [expr {$y + $h - $top}]
    set legendW [expr {$o(-legend) ? $w * 0.38 : 0}]
    set d  [expr {min($avail, $w - $legendW)}]
    set r  [expr {$d / 2.0 - 2}]
    set cx [expr {$x + ($w - $legendW) / 2.0}]
    set cy [expr {$top + $avail / 2.0}]

    set start 90.0
    set i 0
    foreach p $pairs {
        lassign $p label v
        set extent [expr {-360.0 * $v / $total}]
        lassign [_colorFor $opts $i] cr cg cb
        $pdf setFillColor $cr $cg $cb
        $pdf setStrokeColor 1 1 1
        $pdf setLineWidth 0.8
        $pdf arc [expr {$cx - $r}] [expr {$cy - $r}] [expr {2 * $r}] \
                [expr {2 * $r}] $start $extent -style pieslice -filled 1
        set start [expr {$start + $extent}]
        incr i
    }

    if {$o(-legend)} {
        legend $pdf [expr {$x + $w - $legendW + 6}] [expr {$cy - $r}] \
                $pairs $opts -total $total
    }
    $pdf setFillColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
    _endFigure $pdf
    return [expr {$y + $h}]
}

# ---------------------------------------------------------------------------
# legend -- colour swatch, label, share
# ---------------------------------------------------------------------------
proc ::pdf4tcllib::chart::legend {pdf x y pairs opts args} {
    array set o $opts
    set total 0
    foreach {k v} $args {
        switch -- $k {
            -total  { set total $v }
            default { return -code error "chart::legend: unknown option $k" }
        }
    }
    $pdf setFont $o(-labelsize) [::pdf4tcllib::_defaultFamily]
    set lh [expr {$o(-labelsize) * 1.6}]
    set i 0
    foreach p $pairs {
        lassign $p label v
        lassign [_colorFor $opts $i] r g b
        set ly [expr {$y + $i * $lh}]
        $pdf setFillColor $r $g $b
        $pdf rectangle $x $ly $o(-labelsize) $o(-labelsize) -filled 1
        $pdf setFillColor 0.2 0.2 0.2
        set txt $label
        if {$total > 0} {
            append txt [format "  %.0f%%" [expr {100.0 * $v / $total}]]
        }
        ::pdf4tcllib::unicode::safeText $pdf $txt \
                -x [expr {$x + $o(-labelsize) * 1.5}] \
                -y [expr {$ly + $o(-labelsize) * 0.9}]
        incr i
    }
    $pdf setFillColor 0 0 0
    return [expr {$y + $i * $lh}]
}

proc ::pdf4tcllib::chart::configure {args} {
    variable CFG
    if {![llength $args]} { return [array get CFG] }
    if {[llength $args] % 2} {
        return -code error "chart::configure: expected option/value pairs"
    }
    foreach {k v} $args {
        if {![info exists CFG($k)]} {
            return -code error "chart::configure: unknown option $k\
                    (known: [join [lsort [array names CFG]] { }])"
        }
        set CFG($k) $v
    }
    return [array get CFG]
}
