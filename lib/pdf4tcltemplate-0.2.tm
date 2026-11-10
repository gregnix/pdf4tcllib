# pdf4tcltemplate -- documents from a template (block layout) and a data dict
#
# A business document -- delivery note, quotation, invoice, letter -- is a
# handful of blocks at fixed places (sender line, address, reference
# data), a table that runs over as many pages as it needs, and a few
# blocks that follow the table wherever it ends (totals, payment terms,
# closing text). This module draws such a document from two dicts:
#
#   layout   where each block sits and how it looks, in millimetres
#   data     what each block shows, keyed by block id
#
# The layout is what a designer edits and a program stores per document
# type; the data is what the program fills in per document. The module
# does not compute anything: totals, prices and dates arrive as finished
# text. It only places, wraps and breaks pages.
#
# The block dict is the format of tclutils::tulayout and
# tkutils::tkulayoutcanvas (x y w h show, y 0 = in the flow), so a layout
# made with that designer can be drawn here. Neither is required.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Usage:
#   package require pdf4tcltemplate
#
#   set pdf [::pdf4tcl::new %AUTO% -paper a4]
#   ::pdf4tcllib::template::render $pdf $layout $data
#   $pdf write -file out.pdf
#
# Requires: pdf4tcllib 0.6+, pdf4tcl 0.9.4.23+

package require pdf4tcllib 0.6

package provide pdf4tcltemplate 0.2

namespace eval ::pdf4tcllib::template {
    namespace export render check blockOrder paperSize

    variable PAPERS {a4 {210 297} a5 {148 210} letter {215.9 279.4}}
    variable TYPES  {text pairs table image rule}
    variable PAGES  {first all rest last}
    variable RENDER_OPTS {-font -fontbold -startpage -newpage}
    variable MM [expr {72.0 / 25.4}]
}

proc ::pdf4tcllib::template::_err {kind msg} {
    return -code error -errorcode [list PDF4TCLLIB TEMPLATE $kind] "template: $msg"
}

proc ::pdf4tcllib::template::_g {d k {def ""}} {
    if {[dict exists $d $k]} { return [dict get $d $k] }
    return $def
}

# ---------------------------------------------------------------------------
# paperSize, blockOrder, check
# ---------------------------------------------------------------------------

# Width and height in mm: a4, a5, letter, or {w h}.
proc ::pdf4tcllib::template::paperSize {paper} {
    variable PAPERS
    set k [string tolower $paper]
    if {[dict exists $PAPERS $k]} { return [dict get $PAPERS $k] }
    if {[llength $paper] == 2
            && [string is double -strict [lindex $paper 0]]
            && [string is double -strict [lindex $paper 1]]
            && [lindex $paper 0] > 0 && [lindex $paper 1] > 0} {
        return $paper
    }
    _err PAPER "unknown paper \"$paper\": a4, a5, letter or {width height} in mm"
}

proc ::pdf4tcllib::template::blockOrder {layout} {
    dict keys [_g $layout blocks]
}

# Is the block placed in the flow (after the block before it)?
proc ::pdf4tcllib::template::_inFlow {b} {
    if {[_g $b lockedY 0]} { return 1 }
    expr {[_g $b y 0] == 0}
}

# Checks a layout and returns it with defaults filled in. Raises
# {PDF4TCLLIB TEMPLATE <kind>} on the first problem.
proc ::pdf4tcllib::template::check {layout} {
    variable TYPES
    variable PAGES
    if {[catch {dict size $layout}]} { _err LAYOUT "layout must be a dict" }
    if {![dict exists $layout blocks] || [catch {dict size [dict get $layout blocks]}]} {
        _err LAYOUT "layout needs a dict \"blocks\""
    }
    lassign [paperSize [_g $layout paper a4]] pw ph
    set margin [_g $layout margin 20]
    foreach {k v} [list margin $margin top [_g $layout top $margin] \
            bottom [_g $layout bottom [expr {$ph - $margin}]] size [_g $layout size 10]] {
        if {![string is double -strict $v] || $v < 0} {
            _err VALUE "$k must be a number >= 0, not \"$v\""
        }
        dict set layout $k $v
    }
    if {[dict get $layout bottom] <= [dict get $layout top]} {
        _err VALUE "bottom must lie below top"
    }
    dict set layout paper [_g $layout paper a4]
    dict set layout pagew $pw
    dict set layout pageh $ph
    set out {}
    dict for {id b} [dict get $layout blocks] {
        if {[catch {dict size $b}]} { _err BLOCK "block \"$id\" must be a dict" }
        set t [_g $b type text]
        if {$t ni $TYPES} {
            _err TYPE "block \"$id\": unknown type \"$t\", known: [join $TYPES {, }]"
        }
        dict set b type $t
        foreach k {x y w h size leading labelw gap} {
            if {[dict exists $b $k]} {
                set v [dict get $b $k]
                if {![string is double -strict $v] || $v < 0} {
                    _err VALUE "block \"$id\": $k must be a number >= 0, not \"$v\""
                }
            }
        }
        foreach k {show bold lockedY header zebra} {
            if {[dict exists $b $k] && ![string is boolean -strict [dict get $b $k]]} {
                _err VALUE "block \"$id\": $k must be a boolean"
            }
        }
        if {[dict exists $b align] && [dict get $b align] ni {left right center}} {
            _err VALUE "block \"$id\": align must be left, right or center"
        }
        set p [_g $b page first]
        if {$p ni $PAGES} {
            _err VALUE "block \"$id\": page must be [join $PAGES {, }]"
        }
        if {$p ne "first" && [_inFlow $b]} {
            _err VALUE "block \"$id\": page $p needs a fixed y"
        }
        if {[_g $b x 0] + [_g $b w 0] > $pw + 0.001} {
            _err VALUE "block \"$id\": x + w lies outside the page"
        }
        if {$t eq "table"} {
            if {![llength [_g $b cols]]} { _err VALUE "block \"$id\": a table needs cols" }
            dict set b cols [_cols $id $b]
        }
        if {$t eq "image" && ([_g $b w 0] <= 0 || [_g $b h 0] <= 0)} {
            _err VALUE "block \"$id\": an image needs w and h"
        }
        dict set out $id $b
    }
    dict set layout blocks $out
    return $layout
}

# Table columns: "key" or {key k title t w mm align a}. Columns without a
# width share what is left of the block width.
proc ::pdf4tcllib::template::_cols {id b} {
    set cols {}
    set fixed 0.0
    set free 0
    foreach c [dict get $b cols] {
        if {[llength $c] == 1} { set c [dict create key $c] }
        if {[catch {dict size $c}] || ![dict exists $c key]} {
            _err VALUE "block \"$id\": column \"$c\" needs a key"
        }
        if {![dict exists $c title]} { dict set c title [dict get $c key] }
        if {![dict exists $c align]} { dict set c align left }
        if {[dict get $c align] ni {left right center}} {
            _err VALUE "block \"$id\": column [dict get $c key]: align must be left, right or center"
        }
        if {[dict exists $c w]} {
            set fixed [expr {$fixed + [dict get $c w]}]
        } else {
            incr free
        }
        lappend cols $c
    }
    set w [_g $b w 0]
    set rest [expr {$w - $fixed}]
    if {$rest < -0.001 || ($free && $rest <= 0)} {
        _err VALUE "block \"$id\": the columns are wider than the block ($w mm)"
    }
    if {$free} {
        set each [expr {$rest / $free}]
        set cols [lmap c $cols {
            if {![dict exists $c w]} { dict set c w $each }
            set c
        }]
    }
    return $cols
}

# ---------------------------------------------------------------------------
# Units: the layout is in mm and points, the document in its own -unit
# ---------------------------------------------------------------------------

proc ::pdf4tcllib::template::_setup {pdf} {
    variable MM
    variable S
    set unit p
    catch {set unit [$pdf cget -unit]}
    set per 1.0
    if {[info exists ::pdf4tcl::units($unit)]} { set per $::pdf4tcl::units($unit) }
    # mm -> document unit, point -> document unit
    set S(mm) [expr {$MM / $per}]
    set S(pt) [expr {1.0 / $per}]
    set orient 1
    catch {set orient [$pdf cget -orient]}
    if {!$orient} {
        _err ORIENT "the document must use -orient 1 (y from the top)"
    }
}

proc ::pdf4tcllib::template::_u {mm} {
    variable S
    expr {$mm * $S(mm)}
}

# Text width in mm. getStringWidth takes -size in points and answers in
# the document unit.
proc ::pdf4tcllib::template::_width {pdf text font size} {
    variable S
    expr {[$pdf getStringWidth $text -font $font -size $size] / $S(mm)}
}

proc ::pdf4tcllib::template::_color {layout name} {
    if {$name eq ""} { set name text }
    set theme [_g $layout theme]
    if {[dict exists $theme $name]} { set name [dict get $theme $name] }
    if {[llength $name] == 3} { return $name }
    # names a theme does not define
    set std {text {0 0 0} rule {0.6 0.6 0.6} muted {0.4 0.4 0.4} accent {0.15 0.25 0.55}}
    if {[dict exists $std $name]} { return [dict get $std $name] }
    _err VALUE "unknown colour \"$name\" (neither in theme nor r g b)"
}

# ---------------------------------------------------------------------------
# Text: lines, wrapping, placeholders
# ---------------------------------------------------------------------------

# Splits at newlines (a newline must never reach the PDF as a character),
# wraps each line to $w mm, breaks a word longer than the line.
proc ::pdf4tcllib::template::_wrap {pdf text w font size} {
    set out {}
    foreach para [split [string map {\r "" \t " "} $text] \n] {
        set words [regexp -all -inline {\S+} $para]
        if {![llength $words]} { lappend out ""; continue }
        set line ""
        foreach word $words {
            # not [expr {... ? $word : ...}]: expr would return "+49" as 49
            if {$line eq ""} { set try $word } else { set try "$line $word" }
            if {[_width $pdf $try $font $size] <= $w} {
                set line $try
                continue
            }
            if {$line ne ""} { lappend out $line; set line "" }
            # the word alone is too wide: break it into pieces
            while {[_width $pdf $word $font $size] > $w && [string length $word] > 1} {
                set n [string length $word]
                while {$n > 1 && [_width $pdf [string range $word 0 $n-1] $font $size] > $w} {
                    incr n -1
                }
                lappend out [string range $word 0 $n-1]
                set word [string range $word $n end]
            }
            set line $word
        }
        lappend out $line
    }
    return $out
}

# {name} in a layout text -> the data value; {page} and {pages} too.
proc ::pdf4tcllib::template::_subst {text data} {
    variable P
    set map [list "{page}" $P(page) "{pages}" $P(pages)]
    dict for {k v} $data { lappend map "{$k}" $v }
    string map $map $text
}

# What a block shows: data(field) or, if absent, the block's own text.
# Returns {} when there is nothing to show.
proc ::pdf4tcllib::template::_value {b id data} {
    set f [_g $b field $id]
    if {[dict exists $data $f]} { return [list 1 [dict get $data $f]] }
    if {[dict exists $b text]} { return [list 1 [_subst [dict get $b text] $data]] }
    return {0 {}}
}

proc ::pdf4tcllib::template::_font {b} {
    variable F
    if {[_g $b bold 0]} { return $F(bold) }
    return $F(normal)
}

proc ::pdf4tcllib::template::_leading {layout b} {
    set size [_g $b size [dict get $layout size]]
    if {[dict exists $b leading]} { return [expr {[dict get $b leading] / 72.0 * 25.4}] }
    expr {$size * 1.3 / 72.0 * 25.4}
}

# One line of text with its top at $y (mm).
proc ::pdf4tcllib::template::_line {pdf text x y w align font size rgb} {
    variable S
    if {$text eq ""} return
    $pdf setFont [expr {$size * $S(pt)}] $font
    lassign $rgb r g bl
    $pdf setFillColor $r $g $bl
    # baseline: top plus ascent (about 0.8 of the size for usual faces)
    set asc [expr {0.8 * $size / 72.0 * 25.4}]
    catch {set asc [expr {[$pdf getFontMetric ascend] / $S(mm)}]}
    set by [expr {$y + $asc}]
    switch -- $align {
        right  { $pdf text $text -x [_u [expr {$x + $w}]] -y [_u $by] -align right }
        center { $pdf text $text -x [_u [expr {$x + $w / 2.0}]] -y [_u $by] -align center }
        default { $pdf text $text -x [_u $x] -y [_u $by] }
    }
    $pdf setFillColor 0 0 0
}

# ---------------------------------------------------------------------------
# render
# ---------------------------------------------------------------------------
#
# Options:
#   -font f       font for normal text (default: pdf4tcllib's sans face)
#   -fontbold f   font for bold text (default: its bold face, else -font)
#   -startpage 1  render opens the first page and closes the last; 0 when
#                 the caller has a page open and closes it himself
#   -newpage s    script run after each page break, in the caller's scope
#
# Returns a dict: pages (number of pages), y (mm below the last block).
proc ::pdf4tcllib::template::render {pdf layout data args} {
    variable RENDER_OPTS
    if {[llength $args] % 2} { _err OPTION "options come in pairs" }
    set o [dict create -font "" -fontbold "" -startpage 1 -newpage ""]
    foreach {k v} $args {
        if {$k ni $RENDER_OPTS} {
            _err OPTION "unknown option \"$k\", known: [join $RENDER_OPTS {, }]"
        }
        dict set o $k $v
    }
    set layout [check $layout]
    if {[catch {dict size $data}]} { _err DATA "data must be a dict" }
    _fonts [dict get $o -font] [dict get $o -fontbold]

    # {pages} needs the page count before the first page is drawn: a
    # dry run into a throw-away document, same paper, unit and fonts.
    set total ""
    if {[string first "{pages}" $layout] >= 0} {
        set unit p
        catch {set unit [$pdf cget -unit]}
        set dry [::pdf4tcl::new %AUTO% -paper [_pdfPaper $layout] -unit $unit -orient 1]
        try {
            set total [dict get [_render $dry $layout $data 1 "" ""] pages]
        } finally {
            catch {$dry destroy}
        }
        _fonts [dict get $o -font] [dict get $o -fontbold]
    }
    uplevel 1 [list ::pdf4tcllib::template::_render $pdf $layout $data \
        [dict get $o -startpage] $total [dict get $o -newpage]]
}

proc ::pdf4tcllib::template::_pdfPaper {layout} {
    set p [_g $layout paper a4]
    if {[llength $p] == 2} {
        return [list [expr {[lindex $p 0] * 72.0 / 25.4}] [expr {[lindex $p 1] * 72.0 / 25.4}]]
    }
    return $p
}

proc ::pdf4tcllib::template::_fonts {normal bold} {
    variable F
    if {$normal eq ""} { set normal [::pdf4tcllib::_defaultFamily] }
    if {$bold eq ""} {
        if {$normal eq "Helvetica"} {
            set bold Helvetica-Bold
        } elseif {![catch {::pdf4tcllib::fonts::ready} r] && $r
                  && $normal eq [::pdf4tcllib::fonts::fontSans]} {
            set bold [::pdf4tcllib::fonts::fontSansBold]
        } else {
            set bold $normal
        }
    }
    set F(normal) $normal
    set F(bold) $bold
}

proc ::pdf4tcllib::template::_render {pdf layout data startpage total newpage} {
    variable P
    variable IMG
    _setup $pdf
    array unset IMG $pdf,*
    set P(pdf) $pdf
    set P(layout) $layout
    set P(data) $data
    set P(page) 1
    set P(pages) $total
    set P(newpage) $newpage
    set P(level) [expr {[info level] - 1}]
    if {$startpage} { $pdf startPage }
    _repeating all
    set y [dict get $layout top]
    dict for {id b} [dict get $layout blocks] {
        if {![_g $b show 1] || [_g $b page first] ne "first"} continue
        if {[_inFlow $b]} {
            set top [expr {$y + [_g $b gap 0]}]
        } else {
            set top [_g $b y]
        }
        set end [_block $id $b $top [_inFlow $b]]
        if {$end ne ""} { set y $end }
    }
    _repeating last
    if {$startpage} { $pdf endPage }
    return [dict create pages $P(page) y $y]
}

# Blocks with page all / rest / last on the current page.
proc ::pdf4tcllib::template::_repeating {which} {
    variable P
    dict for {id b} [dict get $P(layout) blocks] {
        if {![_g $b show 1]} continue
        set p [_g $b page first]
        set draw [switch -- $which {
            all  { expr {$p eq "all" || ($p eq "rest" && $P(page) > 1)} }
            last { expr {$p eq "last"} }
        }]
        if {$draw} { _block $id $b [_g $b y] 0 }
    }
}

proc ::pdf4tcllib::template::_newPage {} {
    variable P
    $P(pdf) endPage
    $P(pdf) startPage
    incr P(page)
    if {$P(newpage) ne ""} { uplevel #$P(level) $P(newpage) }
    _repeating all
    return [dict get $P(layout) top]
}

# Room on this page below $y?
proc ::pdf4tcllib::template::_fits {y h} {
    variable P
    expr {$y + $h <= [dict get $P(layout) bottom] + 0.001}
}

# Draws one block with its top at $y; returns the y below it, or "" when
# the block showed nothing.
proc ::pdf4tcllib::template::_block {id b y flow} {
    variable P
    lassign [_value $b $id $P(data)] has v
    set t [dict get $b type]
    if {!$has && $t ni {rule}} { return "" }
    switch -- $t {
        text  { return [_text $id $b $v $y $flow] }
        pairs { return [_pairs $id $b $v $y $flow] }
        table { return [_table $id $b $v $y] }
        image { return [_image $id $b $v $y] }
        rule  { return [_rule $b $y] }
    }
}

proc ::pdf4tcllib::template::_text {id b v y flow} {
    variable P
    set layout $P(layout)
    set size [_g $b size [dict get $layout size]]
    set font [_font $b]
    set rgb [_color $layout [_g $b color text]]
    set w [_g $b w [expr {[dict get $layout pagew] - 2 * [dict get $layout margin]}]]
    set x [_g $b x [dict get $layout margin]]
    # a list block: one entry per line, empty entries dropped (addresses)
    if {[_g $b list 0]} {
        set v [join [lmap l $v { if {[string trim $l] eq ""} continue; set l }] \n]
    }
    set lines [_wrap $P(pdf) $v $w $font $size]
    if {![llength $lines] || ([llength $lines] == 1 && [lindex $lines 0] eq "")} { return "" }
    set lh [_leading $layout $b]
    # keep short blocks together; long ones break between lines
    if {$flow && ![_fits $y [expr {[llength $lines] * $lh}]]
            && [llength $lines] * $lh <= [dict get $layout bottom] - [dict get $layout top]} {
        set y [_newPage]
    }
    ::pdf4tcllib::tag::begin $P(pdf) P
    foreach l $lines {
        if {$flow && ![_fits $y $lh]} {
            ::pdf4tcllib::tag::end $P(pdf)
            set y [_newPage]
            ::pdf4tcllib::tag::begin $P(pdf) P
        }
        _line $P(pdf) $l $x $y $w [_g $b align left] $font $size $rgb
        set y [expr {$y + $lh}]
    }
    ::pdf4tcllib::tag::end $P(pdf)
    return $y
}

# label value label value ...: labels left in labelw, values beside them.
proc ::pdf4tcllib::template::_pairs {id b v y flow} {
    variable P
    variable F
    set layout $P(layout)
    if {[llength $v] % 2} { _err DATA "block \"$id\": pairs need an even list" }
    set size [_g $b size [dict get $layout size]]
    set rgb [_color $layout [_g $b color text]]
    set x [_g $b x [dict get $layout margin]]
    set w [_g $b w 80]
    set lw [_g $b labelw [expr {$w / 2.0}]]
    set lh [_leading $layout $b]
    set rows {}
    foreach {k val} $v {
        if {[string trim $val] eq "" && [_g $b skipempty 1]} continue
        lappend rows $k $val
    }
    if {![llength $rows]} { return "" }
    set vw [expr {$w - $lw}]
    set wrapped {}
    set n 0
    foreach {k val} $rows {
        set ll [_wrap $P(pdf) $val $vw [_font $b] $size]
        lappend wrapped $k $ll
        incr n [llength $ll]
    }
    if {$flow && ![_fits $y [expr {$n * $lh}]]} { set y [_newPage] }
    ::pdf4tcllib::tag::begin $P(pdf) P
    foreach {k ll} $wrapped {
        _line $P(pdf) $k $x $y $lw left $F(normal) $size $rgb
        foreach l $ll {
            _line $P(pdf) $l [expr {$x + $lw}] $y $vw [_g $b align left] [_font $b] $size $rgb
            set y [expr {$y + $lh}]
        }
    }
    ::pdf4tcllib::tag::end $P(pdf)
    return $y
}

# Rows are dicts (keys of the columns) or lists (in column order). A cell
# wraps inside its column; a row never splits; the head repeats on every
# page.
#
# A row dict may carry row keys besides the column keys:
#   _kind group   a heading row: bold, across all columns, kept with the
#                 row after it (never alone at the bottom of a page)
#   _kind sum     a totals row: bold, a thin rule above, kept with the row
#                 before it (never alone at the top of a page)
#   _kind total   like sum, with a stronger rule
#   _span 1       the row's text runs across all columns; the text is
#                 _text or the value of the first column
# Rows that hold together form a chain; a chain that fits on an empty page
# starts on a new page when it does not fit in what is left. A longer
# chain breaks row by row. Zebra shading counts plain rows only.
proc ::pdf4tcllib::template::_table {id b rows y} {
    variable P
    variable F
    set pdf $P(pdf)
    set layout $P(layout)
    set size [_g $b size [dict get $layout size]]
    set rgb [_color $layout [_g $b color text]]
    set rule [_color $layout [_g $b rule {0.6 0.6 0.6}]]
    set x0 [_g $b x [dict get $layout margin]]
    set cols [dict get $b cols]
    set lh [_leading $layout $b]
    set pad 1.0
    set keys [lmap c $cols { dict get $c key }]
    set tw [_tableW $cols]
    # rows -> {kind span cells wrapped h}
    set plan {}
    foreach row $rows {
        set isDict [expr {![catch {dict size $row}] && ([llength [lmap k [concat $keys {_kind _span _text}] {
            expr {[dict exists $row $k] ? 1 : [continue]} }]])}]
        set kind ""
        set span 0
        if {$isDict} {
            set kind [_g $row _kind ""]
            if {$kind ni {"" group sum total}} {
                _err DATA "block \"$id\": unknown row kind \"$kind\" (group, sum, total)"
            }
            set span [_g $row _span [expr {$kind eq "group"}]]
            set cells [lmap k $keys { _g $row $k }]
        } else {
            set cells $row
        }
        set font [expr {$kind eq "" ? $F(normal) : $F(bold)}]
        if {$span} {
            set t [expr {$isDict && [dict exists $row _text] ? [dict get $row _text] : [lindex $cells 0]}]
            set wrapped [list [_wrap $pdf $t [expr {$tw - 2 * $pad}] $font $size]]
            set lines [llength [lindex $wrapped 0]]
        } else {
            set wrapped {}
            set lines 1
            foreach c $cols cell $cells {
                set ww [_wrap $pdf $cell [expr {[dict get $c w] - 2 * $pad}] $font $size]
                lappend wrapped $ww
                if {[llength $ww] > $lines} { set lines [llength $ww] }
            }
        }
        if {$lines < 1} { set lines 1 }
        lappend plan [dict create kind $kind span $span wrapped $wrapped font $font \
            h [expr {$lines * $lh + $pad}] text [expr {$span ? $t : ""}]]
    }
    # chains: row i holds to i+1 when i is a heading or i+1 a totals row
    set n [llength $plan]
    set chainEnd {}
    for {set i [expr {$n - 1}]} {$i >= 0} {incr i -1} {
        set e $i
        if {$i < $n - 1 && ([dict get [lindex $plan $i] kind] eq "group"
                || [dict get [lindex $plan $i+1] kind] in {sum total})} {
            set e [lindex $chainEnd 0]
        }
        set chainEnd [linsert $chainEnd 0 $e]
    }
    set headH [expr {[_g $b header 1] ? $lh + $pad : 0}]
    set room [expr {[dict get $layout bottom] - [dict get $layout top] - $headH}]
    ::pdf4tcllib::tag::begin $pdf Table
    if {[_g $b header 1]} { set y [_tableHead $b $cols $x0 $y $size $lh $pad] }
    set zebra 0
    set chainTo -1
    for {set i 0} {$i < $n} {incr i} {
        set r [lindex $plan $i]
        set h [dict get $r h]
        set need $h
        # first row of a chain: the whole chain, if it fits on a page at all
        if {$i > $chainTo} {
            set chainTo [lindex $chainEnd $i]
            set ch 0.0
            for {set j $i} {$j <= $chainTo} {incr j} { set ch [expr {$ch + [dict get [lindex $plan $j] h]}] }
            if {$ch <= $room + 0.001} { set need $ch }
        }
        if {![_fits $y $need]} {
            ::pdf4tcllib::tag::end $pdf
            set y [_newPage]
            ::pdf4tcllib::tag::begin $pdf Table
            if {[_g $b header 1]} { set y [_tableHead $b $cols $x0 $y $size $lh $pad] }
        }
        set kind [dict get $r kind]
        if {$kind eq ""} {
            incr zebra
            if {[_g $b zebra 0] && $zebra % 2 == 0} {
                ::pdf4tcllib::tag::artifact $pdf
                $pdf setFillColor 0.95 0.95 0.95
                # starts below the rule of the row above, which it would hide
                $pdf rectangle [_u $x0] [_u [expr {$y + 0.3}]] [_u $tw] \
                    [_u [expr {$h - 0.3}]] -filled 1 -stroke 0
                $pdf setFillColor 0 0 0
                ::pdf4tcllib::tag::artifactEnd $pdf
            }
        } elseif {$kind in {sum total}} {
            _hline $pdf $x0 $y $tw $rgb [expr {$kind eq "total" ? 0.8 : 0.4}]
        }
        ::pdf4tcllib::tag::begin $pdf TR
        if {[dict get $r span]} {
            ::pdf4tcllib::tag::begin $pdf TD
            set ly [expr {$y + $pad / 2.0}]
            foreach l [lindex [dict get $r wrapped] 0] {
                _line $pdf $l [expr {$x0 + $pad}] $ly [expr {$tw - 2 * $pad}] left \
                    [dict get $r font] $size $rgb
                set ly [expr {$ly + $lh}]
            }
            ::pdf4tcllib::tag::end $pdf
        } else {
            set x $x0
            foreach c $cols ww [dict get $r wrapped] {
                ::pdf4tcllib::tag::begin $pdf TD
                set ly [expr {$y + $pad / 2.0}]
                foreach l $ww {
                    _line $pdf $l [expr {$x + $pad}] $ly [expr {[dict get $c w] - 2 * $pad}] \
                        [dict get $c align] [dict get $r font] $size $rgb
                    set ly [expr {$ly + $lh}]
                }
                ::pdf4tcllib::tag::end $pdf
                set x [expr {$x + [dict get $c w]}]
            }
        }
        ::pdf4tcllib::tag::end $pdf
        set y [expr {$y + $h}]
        # a heading has no line under it: it belongs to the rows below
        if {$kind ne "group"} { _hline $pdf $x0 $y $tw $rule 0.2 }
    }
    ::pdf4tcllib::tag::end $pdf
    return $y
}

proc ::pdf4tcllib::template::_tableW {cols} {
    set w 0.0
    foreach c $cols { set w [expr {$w + [dict get $c w]}] }
    return $w
}

proc ::pdf4tcllib::template::_tableHead {b cols x0 y size lh pad} {
    variable P
    variable F
    set pdf $P(pdf)
    set rgb [_color $P(layout) [_g $b color text]]
    set rule [_color $P(layout) [_g $b rule {0.6 0.6 0.6}]]
    ::pdf4tcllib::tag::begin $pdf TR
    set x $x0
    foreach c $cols {
        ::pdf4tcllib::tag::begin $pdf TH -scope Column
        set t [lindex [_wrap $pdf [dict get $c title] [expr {[dict get $c w] - 2 * $pad}] \
            $F(bold) $size] 0]
        _line $pdf $t [expr {$x + $pad}] [expr {$y + $pad / 2.0}] \
            [expr {[dict get $c w] - 2 * $pad}] [dict get $c align] $F(bold) $size $rgb
        ::pdf4tcllib::tag::end $pdf
        set x [expr {$x + [dict get $c w]}]
    }
    ::pdf4tcllib::tag::end $pdf
    set y [expr {$y + $lh + $pad}]
    _hline $pdf $x0 $y [_tableW $cols] $rule 0.5
    return $y
}

proc ::pdf4tcllib::template::_hline {pdf x y w rgb width} {
    variable S
    ::pdf4tcllib::tag::artifact $pdf
    lassign $rgb r g bl
    $pdf setStrokeColor $r $g $bl
    $pdf setLineWidth [expr {$width * $S(pt)}]
    $pdf line [_u $x] [_u $y] [_u [expr {$x + $w}]] [_u $y]
    $pdf setStrokeColor 0 0 0
    $pdf setLineWidth $S(pt)
    ::pdf4tcllib::tag::artifactEnd $pdf
}

proc ::pdf4tcllib::template::_rule {b y} {
    variable P
    set layout $P(layout)
    set x [_g $b x [dict get $layout margin]]
    set w [_g $b w [expr {[dict get $layout pagew] - 2 * [dict get $layout margin]}]]
    _hline $P(pdf) $x $y $w [_color $layout [_g $b color rule]] [_g $b size 0.5]
    return $y
}

# An image file, fitted into w x h with its aspect kept, top left (or as
# align says along the width). A full page block at x 0 y 0 drawn first is
# a letterhead.
proc ::pdf4tcllib::template::_image {id b file y} {
    variable P
    variable IMG
    set pdf $P(pdf)
    if {![file readable $file]} { _err DATA "block \"$id\": image \"$file\" not readable" }
    if {![info exists IMG($pdf,$file)]} {
        set IMG($pdf,$file) [$pdf addImage $file]
    }
    set img $IMG($pdf,$file)
    lassign [$pdf getImageSize $img] iw ih
    set bw [dict get $b w]
    set bh [dict get $b h]
    set f [expr {min($bw / double($iw), $bh / double($ih))}]
    set w [expr {$iw * $f}]
    set h [expr {$ih * $f}]
    set x [_g $b x 0]
    switch -- [_g $b align left] {
        right  { set x [expr {$x + $bw - $w}] }
        center { set x [expr {$x + ($bw - $w) / 2.0}] }
    }
    ::pdf4tcllib::tag::artifact $pdf
    $pdf putImage $img [_u $x] [_u $y] -width [_u $w] -height [_u $h]
    ::pdf4tcllib::tag::artifactEnd $pdf
    return [expr {$y + $h}]
}
