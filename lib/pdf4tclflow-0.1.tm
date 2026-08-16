# pdf4tclflow -- text flowing through columns and pages
#
# text::writeParagraph sets one paragraph in one box. What is missing is
# the thing a newsletter or a two-column report needs: a body of text that
# fills column one, continues in column two, and carries on at the top of
# the next page.
#
# The module does the arithmetic and hands the page break back to the
# caller, because only the caller knows what a new page needs -- a running
# head, a watermark, a different first page.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Usage:
#   package require pdf4tclflow
#
#   ::pdf4tcllib::flow::columns $pdf $ctx $text -columns 2 -newpage {
#       $pdf endPage
#       $pdf startPage
#       ::pdf4tcllib::page::header $pdf $ctx "Chapter 1"
#   }
#
# Requires: pdf4tcllib 0.6+, pdf4tcl 0.9.4.23+

package require pdf4tcllib 0.6

package provide pdf4tclflow 0.1

namespace eval ::pdf4tcllib::flow {
    namespace export columns measure boxes

    variable CFG
    array set CFG {
        -columns   2
        -gap       18
        -size      10
        -font      {}
        -align     left
        -tag       P
        -top       {}
        -bottom    {}
        -newpage   {}
        -firstx    {}
        -firsty    {}
    }
}

proc ::pdf4tcllib::flow::_opts {who args} {
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
    if {$o(-columns) < 1} {
        return -code error "$who: -columns must be at least 1"
    }
    return [array get o]
}

# ---------------------------------------------------------------------------
# boxes -- where the columns sit
# ---------------------------------------------------------------------------
#
# Returns a list of {x width} pairs. Public because a caller who wants to
# put a picture in column two needs the same arithmetic.
proc ::pdf4tcllib::flow::boxes {ctx args} {
    set opts [_opts "flow::boxes" {*}$args]
    array set o $opts
    set left  [dict get $ctx left]
    set total [dict get $ctx text_w]
    set n     $o(-columns)
    set colW  [expr {($total - ($n - 1) * $o(-gap)) / double($n)}]
    if {$colW <= 0} {
        return -code error "flow::boxes: $n columns with a gap of\
                $o(-gap) pt leave no width in [format %.1f $total] pt"
    }
    set out {}
    for {set i 0} {$i < $n} {incr i} {
        lappend out [list [expr {$left + $i * ($colW + $o(-gap))}] $colW]
    }
    return $out
}

# ---------------------------------------------------------------------------
# measure -- how many lines does this text make in one column?
# ---------------------------------------------------------------------------
#
# Splits at blank lines into paragraphs and wraps each to the column width.
# Returns a list of lines, with an empty string where a paragraph ends --
# that empty string is the paragraph gap, and keeping it in the line list
# is what makes the column arithmetic below one loop instead of two.
proc ::pdf4tcllib::flow::measure {pdf text width size font} {
    set lines {}
    set paras [regexp -all -inline {[^\n]+(?:\n(?!\s*\n)[^\n]+)*} $text]
    if {![llength $paras]} { return {} }
    set first 1
    foreach p $paras {
        if {!$first} { lappend lines "" }
        set first 0
        set p [regsub -all {\s+} [string trim $p] " "]
        foreach l [::pdf4tcllib::text::wrap $p $width $size $font 0 $pdf] {
            lappend lines $l
        }
    }
    return $lines
}

# ---------------------------------------------------------------------------
# columns -- the flow itself
# ---------------------------------------------------------------------------
#
# Fills column after column, page after page, until the text is used up.
# Returns a dict:
#
#   column   the column the text ended in (0-based)
#   y        the y below the last line
#   pages    how many page breaks were made
#   lines    how many lines were set in total
#
# -newpage is a script, run in the caller's scope whenever a new page is
# needed. It must leave a page open. Without it the flow stops at the end
# of the last column and returns what is left in `rest` -- silently
# dropping text would be the worse answer.
proc ::pdf4tcllib::flow::columns {pdf ctx text args} {
    set opts [_opts "flow::columns" {*}$args]
    array set o $opts
    if {$o(-font) eq ""} { set o(-font) [::pdf4tcllib::_defaultFamily] }
    set top    [expr {$o(-top)    eq "" ? [dict get $ctx top]    : $o(-top)}]
    set bottom [expr {$o(-bottom) eq "" ? [dict get $ctx bottom] : $o(-bottom)}]

    set cols [boxes $ctx {*}[array get o]]
    set lh   [::pdf4tcllib::page::lineheight $o(-size)]
    set lines [measure $pdf $text [lindex $cols 0 1] $o(-size) $o(-font)]

    set col   0
    set y     [expr {$o(-firsty) eq "" ? $top : $o(-firsty)}]
    set pages 0
    set set_  0

    $pdf setFont $o(-size) $o(-font)
    if {$o(-tag) ne ""} { ::pdf4tcllib::tag::begin $pdf $o(-tag) }

    set i 0
    set n [llength $lines]
    while {$i < $n} {
        set line [lindex $lines $i]

        # Does the next line still fit into this column?
        if {$y + $lh > $bottom} {
            incr col
            if {$col >= [llength $cols]} {
                if {$o(-newpage) eq ""} {
                    # Out of columns and no way to make more. Say so rather
                    # than drop the rest on the floor.
                    if {$o(-tag) ne ""} { ::pdf4tcllib::tag::end $pdf }
                    return [dict create column [expr {[llength $cols] - 1}] \
                            y $y pages $pages lines $set_ \
                            rest [join [lrange $lines $i end] "\n"]]
                }
                if {$o(-tag) ne ""} { ::pdf4tcllib::tag::end $pdf }
                uplevel 1 $o(-newpage)
                if {$o(-tag) ne ""} { ::pdf4tcllib::tag::begin $pdf $o(-tag) }
                $pdf setFont $o(-size) $o(-font)
                incr pages
                set col 0
            }
            set y $top
            # A column never starts with the blank line that separates two
            # paragraphs -- that is what leaves a stray gap at the top.
            if {$line eq ""} { incr i ; continue }
        }

        if {$line ne ""} {
            lassign [lindex $cols $col] cx cw
            ::pdf4tcllib::unicode::safeText $pdf $line -x $cx -y $y
            incr set_
        }
        set y [expr {$y + $lh}]
        incr i
    }
    if {$o(-tag) ne ""} { ::pdf4tcllib::tag::end $pdf }

    return [dict create column $col y $y pages $pages lines $set_ rest ""]
}

proc ::pdf4tcllib::flow::configure {args} {
    variable CFG
    if {![llength $args]} { return [array get CFG] }
    if {[llength $args] % 2} {
        return -code error "flow::configure: expected option/value pairs"
    }
    foreach {k v} $args {
        if {![info exists CFG($k)]} {
            return -code error "flow::configure: unknown option $k\
                    (known: [join [lsort [array names CFG]] { }])"
        }
        set CFG($k) $v
    }
    return [array get CFG]
}
