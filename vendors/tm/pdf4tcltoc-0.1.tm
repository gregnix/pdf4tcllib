# pdf4tcltoc -- table of contents with real page numbers
#
# The awkward part of a table of contents is not the dot leaders, it is
# that the page number of a heading is only known once the document has
# been laid out -- and inserting the contents page at the front shifts
# every one of those numbers. This module solves that the way typesetters
# always have: lay the document out twice.
#
#   pass 1   run the caller's content script into a throwaway document,
#            collect every heading with the page it landed on
#   pass 2   knowing how many pages the contents itself needs, run the
#            same script again into the real document, with the contents
#            written first
#
# The caller writes the content once, as a script, and marks headings with
# toc::heading instead of writing them by hand.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Usage:
#   package require pdf4tcltoc
#
#   ::pdf4tcllib::toc::document $pdf a4 {
#       ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Introduction"
#       set y [::pdf4tcllib::text::writeParagraph $pdf $body $x $y $w]
#       ...
#   } -title "Contents"
#
# Requires: pdf4tcllib 0.6+, pdf4tcl 0.9.4.23+

package require pdf4tcllib 0.6

package provide pdf4tcltoc 0.1

namespace eval ::pdf4tcllib::toc {
    namespace export document heading collect render entries pageCount

    # Entries of the current collection: a list of {level title page}.
    variable ENTRIES {}
    # Are we collecting? Only true during pass 1.
    variable COLLECT 0
    # How many pages the contents occupies -- added to every page number
    # collected in pass 1, because the contents goes in front of them.
    variable OFFSET 0

    variable CFG
    array set CFG {
        -title       "Contents"
        -titlesize   16
        -size        11
        -leader      "."
        -indent      14
        -gap         4
        -bookmarks   1
        -pagelabels  0
    }
}

# ---------------------------------------------------------------------------
# heading -- write a heading and record it
# ---------------------------------------------------------------------------
#
# Draws the heading through text::writeParagraph with the matching
# structure type (level 1 -> H1) and, in pass 1, records title and page.
#
#   level  1..6
#   text   the heading
#   -size  font size; default is 18 minus 2 per level, floored at 10
#   -tag   structure type; default H<level>
#
# Advances yVar past the heading. Returns the new y.
proc ::pdf4tcllib::toc::heading {pdf ctx yVar level text args} {
    variable ENTRIES
    variable COLLECT
    variable OFFSET
    variable CFG
    upvar 1 $yVar y

    array set opts [list -size {} -tag {} -gap $CFG(-gap)]
    foreach {k v} $args {
        if {![info exists opts($k)]} {
            return -code error "toc::heading: unknown option $k\
                    (known: [join [lsort [array names opts]] { }])"
        }
        set opts($k) $v
    }
    if {![string is integer -strict $level] || $level < 1 || $level > 6} {
        return -code error "toc::heading: level must be 1..6, got \"$level\""
    }
    if {$opts(-size) eq ""} {
        set opts(-size) [expr {max(10, 18 - 2 * $level)}]
    }
    if {$opts(-tag) eq ""} { set opts(-tag) H$level }

    if {$COLLECT} {
        lappend ENTRIES [list $level $text [expr {[$pdf currentPage] + $OFFSET}]]
    }
    if {$CFG(-bookmarks) && !$COLLECT} {
        # A bookmark per heading, at the same nesting. Titles go through
        # the unicode helper: a bookmark title is document content too.
        catch {$pdf bookmarkAdd -title [::pdf4tcllib::unicode::sanitize $text] \
                -level [expr {$level - 1}]}
    }

    set x [dict get $ctx left]
    set w [dict get $ctx text_w]
    set y [::pdf4tcllib::text::writeParagraph $pdf $text $x $y $w \
            $opts(-size) left $opts(-tag)]
    ::pdf4tcllib::page::_advance $ctx y $opts(-gap)
    return $y
}

# ---------------------------------------------------------------------------
# collect -- run a script in collecting mode
# ---------------------------------------------------------------------------
#
# Runs $script in the caller's scope with collection switched on and
# returns the entries. $offset is added to every page number.
#
# Public because a caller who lays out pages by hand can use the two
# halves separately; `document` is the convenient way.
proc ::pdf4tcllib::toc::collect {script {offset 0}} {
    variable ENTRIES
    variable COLLECT
    variable OFFSET
    set ENTRIES {}
    set COLLECT 1
    set OFFSET  $offset
    set rc [catch {uplevel 1 $script} err opts]
    set COLLECT 0
    set OFFSET  0
    if {$rc} { return -options $opts $err }
    return $ENTRIES
}

proc ::pdf4tcllib::toc::entries {} {
    variable ENTRIES
    return $ENTRIES
}

# ---------------------------------------------------------------------------
# pageCount -- how many pages will the contents take?
# ---------------------------------------------------------------------------
#
# Needed before writing anything, because the answer decides the page
# numbers. Counted from the same arithmetic render uses.
proc ::pdf4tcllib::toc::pageCount {ctx entries args} {
    variable CFG
    array set opts [array get CFG]
    foreach {k v} $args {
        if {![info exists opts($k)]} {
            return -code error "toc::pageCount: unknown option $k"
        }
        set opts($k) $v
    }
    if {![llength $entries]} { return 0 }

    set lh     [::pdf4tcllib::page::lineheight $opts(-size)]
    set top    [dict get $ctx top]
    set bottom [dict get $ctx bottom]
    set avail  [expr {abs($bottom - $top)}]
    # The title costs its own line plus a gap, on the first page only.
    set firstAvail [expr {$avail - [::pdf4tcllib::page::lineheight \
            $opts(-titlesize)] - $opts(-gap) * 2}]

    set perFirst [expr {int($firstAvail / $lh)}]
    set perRest  [expr {int($avail / $lh)}]
    if {$perFirst < 1} { set perFirst 1 }
    if {$perRest  < 1} { set perRest  1 }

    set n [llength $entries]
    if {$n <= $perFirst} { return 1 }
    return [expr {1 + int(ceil(double($n - $perFirst) / $perRest))}]
}

# ---------------------------------------------------------------------------
# render -- write the contents pages
# ---------------------------------------------------------------------------
#
# Opens and closes its own pages. Returns the number of pages written,
# which must equal what pageCount promised -- `document` checks that.
proc ::pdf4tcllib::toc::render {pdf ctx entries args} {
    variable CFG
    array set opts [array get CFG]
    foreach {k v} $args {
        if {![info exists opts($k)]} {
            return -code error "toc::render: unknown option $k\
                    (known: [join [lsort [array names opts]] { }])"
        }
        set opts($k) $v
    }
    if {![llength $entries]} { return 0 }

    set x      [dict get $ctx left]
    set right  [dict get $ctx right]
    set top    [dict get $ctx top]
    set bottom [dict get $ctx bottom]
    set lh     [::pdf4tcllib::page::lineheight $opts(-size)]
    set font   [::pdf4tcllib::_defaultFamily]

    set pages 0
    set y $top
    set first 1
    set open 0

    foreach e $entries {
        lassign $e level title page

        if {!$open} {
            $pdf startPage -paper [dict get $ctx paper]
            incr pages
            set open 1
            set y $top
            ::pdf4tcllib::tag::begin $pdf TOC
            if {$first} {
                set y [::pdf4tcllib::text::writeParagraph $pdf $opts(-title) \
                        $x $y [dict get $ctx text_w] $opts(-titlesize) left H1]
                ::pdf4tcllib::page::_advance $ctx y [expr {$opts(-gap) * 2}]
                set first 0
            }
        }

        # One entry: title left, page number right, dot leaders between.
        # The whole line is one TOCI element -- a reader announces it as
        # one item, not as three loose runs of text.
        ::pdf4tcllib::tag::begin $pdf TOCI
        $pdf setFont $opts(-size) $font
        set indent [expr {($level - 1) * $opts(-indent)}]
        set tx     [expr {$x + $indent}]
        set num    $page
        set numW   [$pdf getStringWidth $num]
        set titleW [$pdf getStringWidth $title]

        # Trim the title before it can run into the page number.
        set roomW [expr {$right - $tx - $numW - 12}]
        if {$titleW > $roomW} {
            set title  [::pdf4tcllib::text::truncate $title $roomW \
                    $opts(-size) $font $pdf]
            set titleW [$pdf getStringWidth $title]
        }

        ::pdf4tcllib::unicode::safeText $pdf $title -x $tx -y $y
        ::pdf4tcllib::unicode::safeText $pdf $num -x $right -y $y -align right

        # The leader is decoration: it carries no meaning and a reader
        # should not announce a row of dots.
        if {$opts(-leader) ne ""} {
            ::pdf4tcllib::tag::artifact $pdf -type Layout
            set dotW [$pdf getStringWidth $opts(-leader)]
            if {$dotW > 0} {
                set fromX [expr {$tx + $titleW + 4}]
                set toX   [expr {$right - $numW - 4}]
                set n     [expr {int(($toX - $fromX) / $dotW)}]
                if {$n > 0} {
                    ::pdf4tcllib::unicode::safeText $pdf \
                            [string repeat $opts(-leader) $n] -x $fromX -y $y
                }
            }
            ::pdf4tcllib::tag::artifactEnd $pdf
        }
        ::pdf4tcllib::tag::end $pdf

        ::pdf4tcllib::page::_advance $ctx y $lh
        if {[expr {abs($y - $top)}] + $lh > [expr {abs($bottom - $top)}]} {
            ::pdf4tcllib::tag::end $pdf
            $pdf endPage
            set open 0
        }
    }
    if {$open} {
        ::pdf4tcllib::tag::end $pdf
        $pdf endPage
    }
    return $pages
}

# ---------------------------------------------------------------------------
# document -- the whole two-pass run
# ---------------------------------------------------------------------------
#
#   ::pdf4tcllib::toc::document $pdf a4 $script ?-option value ...?
#
# $script draws the content and calls toc::heading for its headings. It
# runs TWICE, so it must not have side effects the second run would
# duplicate -- no appending to a file, no counters outside it. It sees the
# variables `pdf` and `ctx`, and starts its own pages.
#
# Returns a dict: entries, tocPages, contentPages.
#
# The page count of the contents is computed before the real run and then
# verified against what render actually wrote: if the two disagree, every
# page number in the contents is off by the difference, and it is better to
# say so than to ship a document whose numbers point one page astray.
proc ::pdf4tcllib::toc::document {pdf paper script args} {
    variable CFG
    array set opts [array get CFG]
    foreach {k v} $args {
        if {![info exists opts($k)]} {
            return -code error "toc::document: unknown option $k\
                    (known: [join [lsort [array names opts]] { }])"
        }
        set opts($k) $v
    }
    set ctx [::pdf4tcllib::page::context $paper]

    # --- pass 1: a throwaway document, only to learn the page numbers
    set probe [::pdf4tcl::new %AUTO% -paper $paper]
    set entries [uplevel 1 [list ::pdf4tcllib::toc::_pass1 $probe $ctx $script]]
    set probePages [$probe pageCount]
    $probe destroy

    # How many pages does the contents need? Every content page number
    # shifts by that much.
    set tocPages [pageCount $ctx $entries {*}[array get opts]]
    set shifted {}
    foreach e $entries {
        lassign $e level title page
        lappend shifted [list $level $title [expr {$page + $tocPages}]]
    }

    # --- the contents, then the content itself
    set written [render $pdf $ctx $shifted {*}[array get opts]]
    if {$written != $tocPages} {
        return -code error "toc::document: the contents was calculated as\
                $tocPages page(s) and written as $written -- every page\
                number in it would be off by [expr {$written - $tocPages}]"
    }
    uplevel 1 [list ::pdf4tcllib::toc::_pass2 $pdf $ctx $script]

    return [dict create entries $shifted tocPages $tocPages \
            contentPages $probePages]
}

# The two passes are separate procedures so that $script sees `pdf` and
# `ctx` as ordinary variables in its own scope, and so the collecting flag
# is cleared even when the script fails.
proc ::pdf4tcllib::toc::_pass1 {pdf ctx script} {
    uplevel 1 [list set pdf $pdf]
    uplevel 1 [list set ctx $ctx]
    return [uplevel 1 [list ::pdf4tcllib::toc::collect $script 0]]
}

proc ::pdf4tcllib::toc::_pass2 {pdf ctx script} {
    uplevel 1 [list set pdf $pdf]
    uplevel 1 [list set ctx $ctx]
    uplevel 1 $script
}

# ---------------------------------------------------------------------------
# configure
# ---------------------------------------------------------------------------
proc ::pdf4tcllib::toc::configure {args} {
    variable CFG
    if {![llength $args]} { return [array get CFG] }
    if {[llength $args] % 2} {
        return -code error "toc::configure: expected option/value pairs"
    }
    foreach {k v} $args {
        if {![info exists CFG($k)]} {
            return -code error "toc::configure: unknown option $k\
                    (known: [join [lsort [array names CFG]] { }])"
        }
        set CFG($k) $v
    }
    return [array get CFG]
}
