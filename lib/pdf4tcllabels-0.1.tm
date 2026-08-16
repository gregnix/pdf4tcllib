# pdf4tcllabels-0.1.tm -- label sheets: Zweckform/Avery and friends.
#
#   package require pdf4tcllabels
#   pdf4tcllib::labels::render $pdf 3474 $records {x y w h rec} { ... }
#
# The module owns the geometry -- sheet format, rows, columns, margins,
# pitch, page breaks and where on a part-used sheet to start. What goes on
# a single label is the caller's business, and is written once as a script.

package require Tcl 8.6-
package require pdf4tcl
package require pdf4tcllib

namespace eval ::pdf4tcllib::labels {
    namespace export sheets sheet define render place calibration \
            fitSize wrap ellipsize

    # Sheet catalogue. All values in millimetres, as the manufacturers
    # print them on the box.
    #
    #   w, h        label size
    #   cols, rows  labels per sheet
    #   left, top   margin to the first label
    #   pitchx      column pitch: label width plus the gap to the next
    #   pitchy      row pitch
    #   paper       pdf4tcl paper name
    #
    # Pitch is given separately rather than derived, because several
    # formats have gaps and several do not, and guessing that from the
    # numbers is how labels end up half a millimetre out by the last row.
    #
    # Every entry must fit its sheet: top + (rows-1)*pitchy + h <= page
    # height, and the same across. test_labels.tcl checks that for all of
    # them -- 3475 carried top 4.5, which put its last row 3.6 mm off an A4
    # page (300.6 mm on 297). Seven rows of 42.3 mm need 296.1 mm, so 0.9 mm
    # is left for both margins; 0.45 is that split evenly. Check it against
    # a real sheet before printing a run -- paper is the only measurement
    # that counts here.
    # Roll printers (Zebra, Dymo, Brother) are in here too: one label per
    # page, and the page IS the label. In this module that is a format with
    # cols 1, rows 1 and no margins, and `paper roll` means "the label
    # size" -- sheet() turns it into the {width height} pair pdf4tcl takes
    # for -paper. Nothing else changes: render, place and calibration work
    # as they do for a sheet, and a run of 300 labels becomes 300 pages.
    #
    # NOTE: `#` is not a comment inside these braces -- `array set` reads
    # them as a plain list. Every remark about the catalogue belongs here,
    # above it. (Putting one inside cost me a "list must have an even
    # number of elements" and ten minutes.)
    variable SHEETS
    array set SHEETS {
        3474 {w 70.0  h 37.0  cols 3 rows 8  left 0.0  top 0.0
              pitchx 70.0  pitchy 37.0  paper a4
              desc "Zweckform 3474 -- 24 per sheet, 70 x 37 mm, no gaps"}
        3475 {w 70.0  h 42.3 cols 3 rows 7  left 0.0  top 0.45
              pitchx 70.0  pitchy 42.3 paper a4
              desc "Zweckform 3475 -- 21 per sheet, 70 x 42.3 mm"}
        3483 {w 70.0  h 50.8 cols 3 rows 5  left 0.0  top 21.5
              pitchx 70.0  pitchy 50.8 paper a4
              desc "Zweckform 3483 -- 15 per sheet, 70 x 50.8 mm"}
        3427 {w 105.0 h 148.0 cols 2 rows 2  left 0.0  top 0.0
              pitchx 105.0 pitchy 148.0 paper a4
              desc "Zweckform 3427 -- 4 per sheet, 105 x 148 mm (A6)"}
        4737 {w 63.5  h 29.6 cols 3 rows 9  left 7.25 top 13.0
              pitchx 66.0  pitchy 29.6 paper a4
              desc "Avery 4737 -- 27 per sheet, 63.5 x 29.6 mm, with gaps"}

        dymo-99012 {w 89.0 h 36.0 cols 1 rows 1  left 0.0 top 0.0
              pitchx 89.0  pitchy 36.0 paper roll
              desc "Dymo 99012 -- roll, 89 x 36 mm (large address)"}
        dymo-11354 {w 57.0 h 32.0 cols 1 rows 1  left 0.0 top 0.0
              pitchx 57.0  pitchy 32.0 paper roll
              desc "Dymo 11354 -- roll, 57 x 32 mm (multi purpose)"}
        zebra-100x150 {w 100.0 h 150.0 cols 1 rows 1  left 0.0 top 0.0
              pitchx 100.0 pitchy 150.0 paper roll
              desc "Zebra 100 x 150 mm -- roll, shipping label"}
        brother-62x100 {w 62.0 h 100.0 cols 1 rows 1  left 0.0 top 0.0
              pitchx 62.0  pitchy 100.0 paper roll
              desc "Brother DK-11202 -- roll, 62 x 100 mm (shipping)"}
    }

    # Add or replace a format at run time. The five numbers are on the
    # box; nobody should have to edit this file to use a sheet from the
    # stationery cupboard.
    #
    #   labels::define my {w 48.5 h 25.4 cols 4 rows 10 left 8.0 top 21.5
    #                      pitchx 50.0 pitchy 25.4 paper a4 desc "..."}
    proc define {name spec} {
        variable SHEETS
        foreach k {w h cols rows left top pitchx pitchy} {
            if {![dict exists $spec $k]} {
                return -code error "label format $name: missing \"$k\""
            }
        }
        if {![dict exists $spec paper]} { dict set spec paper a4 }
        if {[dict get $spec paper] eq "roll"
                && ([dict get $spec cols] != 1 || [dict get $spec rows] != 1)} {
            return -code error "label format $name: paper \"roll\" means one\
                    label per page, so cols and rows must both be 1"
        }
        if {![dict exists $spec desc]}  { dict set spec desc  $name }
        set SHEETS($name) $spec
        return $name
    }

    # Known sheet names.
    proc sheets {} {
        variable SHEETS
        return [lsort [array names SHEETS]]
    }

    # Geometry of one sheet, as a dict, in POINTS -- ready to compute with.
    # Millimetres are for the box, points are for the page.
    proc sheet {name} {
        variable SHEETS
        if {![info exists SHEETS($name)]} {
            return -code error "unknown label sheet \"$name\";\
                    known: [join [sheets] {, }]"
        }
        set d $SHEETS($name)
        # "roll" means: the page is the label. pdf4tcl takes a
        # {width height} pair for -paper, so the geometry answers with one
        # -- the caller passes [dict get $geo paper] to startPage either
        # way and never has to know the difference.
        set paper [dict get $d paper]
        if {$paper eq "roll"} {
            set paper [list [::pdf4tcllib::units::mm [dict get $d w]] \
                            [::pdf4tcllib::units::mm [dict get $d h]]]
        }
        set out [dict create name $name \
                paper $paper desc [dict get $d desc] \
                cols [dict get $d cols] rows [dict get $d rows] \
                perSheet [expr {[dict get $d cols] * [dict get $d rows]}]]
        foreach k {w h left top pitchx pitchy} {
            dict set out $k [::pdf4tcllib::units::mm [dict get $d $k]]
            dict set out ${k}mm [dict get $d $k]
        }
        return $out
    }

    # Top left corner of label $idx (0-based) on its sheet, in points,
    # counting left to right and top to bottom.
    proc place {geo idx} {
        set cols [dict get $geo cols]
        set per  [dict get $geo perSheet]
        # render checks -start and -only against perSheet; place is exported
        # and shown directly in the howto. Without this check it answered
        # position 24 of a 24-per-sheet form with the ninth row of an
        # eight-row sheet (y = 839.1 pt), and -1 with a row above the page --
        # both silently.
        if {![string is integer -strict $idx] || $idx < 0 || $idx >= $per} {
            return -code error "\"$idx\" is not a position on sheet\
                    [dict get $geo name] (0..[expr {$per - 1}])"
        }
        set col [expr {$idx % $cols}]
        set row [expr {$idx / $cols}]
        set x [expr {[dict get $geo left] + $col * [dict get $geo pitchx]}]
        set y [expr {[dict get $geo top]  + $row * [dict get $geo pitchy]}]
        return [list $x $y]
    }

    # Render a list of records onto label sheets.
    #
    #   pdf       a pdf4tcl object, no page started yet
    #   name      sheet name, see [sheets]
    #   records   list of anything -- each element is handed to the script
    #   argSpec   {xVar yVar wVar hVar recVar} names the script's arguments
    #   script    draws one label; coordinates are the label's top left
    #             corner and its size, in points
    #
    # Options:
    #   -start N   leave the first N label positions empty. That is what a
    #              part-used sheet needs, and it is the reason this is a
    #              parameter and not something clever: only the person
    #              holding the sheet knows how many are gone.
    #   -frame 0|1 draw a thin outline round every position. For getting the
    #              alignment right on paper -- print one, hold it against a
    #              real sheet. Never for production.
    #   -tag TYPE  structure type each label is wrapped in when tagging is
    #              on, Sect by default. Each label is a unit of its own.
    #
    # Returns the number of sheets written.
    proc render {pdf name records argSpec script args} {
        set opts [dict create -start 0 -frame 0 -tag Sect \
                -offsetx 0.0 -offsety 0.0 -only {}]
        foreach {k v} $args {
            if {![dict exists $opts $k]} {
                return -code error "unknown option \"$k\";\
                        known: [join [dict keys $opts] {, }]"
            }
            dict set opts $k $v
        }
        if {[llength $argSpec] != 5} {
            return -code error "argSpec must name five variables:\
                    {x y w h record}"
        }
        lassign $argSpec vx vy vw vh vrec

        set geo [sheet $name]
        set per [dict get $geo perSheet]

        # Printer offset, in millimetres. Many printers place the image a
        # millimetre or two off; on a borderless sheet like 3474 that puts
        # the first line half outside the label. Measure once per printer
        # with [calibration], then keep the two numbers in a config.
        dict set geo left [expr {[dict get $geo left]
                + [::pdf4tcllib::units::mm [dict get $opts -offsetx]]}]
        dict set geo top  [expr {[dict get $geo top]
                + [::pdf4tcllib::units::mm [dict get $opts -offsety]]}]

        # Which positions to use. -only names them outright, for reprinting
        # single labels onto a part-used sheet: one came out skewed, one is
        # missing, and the rest of the sheet is still good.
        set only [dict get $opts -only]
        set start [dict get $opts -start]
        if {[llength $only]} {
            foreach idx $only {
                if {![string is integer -strict $idx]
                        || $idx < 0 || $idx >= $per} {
                    return -code error "-only: \"$idx\" is not a position\
                            on sheet $name (0..[expr {$per - 1}])"
                }
            }
            if {[llength $only] < [llength $records]} {
                return -code error "-only names [llength $only] position(s)\
                        for [llength $records] record(s)"
            }
        } elseif {$start < 0 || $start >= $per} {
            return -code error "-start must be between 0 and [expr {$per - 1}]\
                    for sheet $name"
        }

        set w [dict get $geo w]
        set h [dict get $geo h]
        set sheetsWritten 0
        set slot $start
        set open 0
        set n -1

        foreach rec $records {
            incr n
            if {[llength $only]} { set slot [lindex $only $n] }
            if {!$open} {
                $pdf startPage -paper [dict get $geo paper]
                incr sheetsWritten
                set open 1
                if {[dict get $opts -frame]} { Frames $pdf $geo }
            }
            lassign [place $geo $slot] x y

            uplevel 1 [list set $vx $x]
            uplevel 1 [list set $vy $y]
            uplevel 1 [list set $vw $w]
            uplevel 1 [list set $vh $h]
            uplevel 1 [list set $vrec $rec]

            # One label is one unit of content. Without this every line of
            # every label lands in the page as a loose run of text.
            ::pdf4tcllib::tag::begin $pdf [dict get $opts -tag]
            uplevel 1 $script
            ::pdf4tcllib::tag::end $pdf

            if {[llength $only]} { continue }
            incr slot
            if {$slot >= $per} {
                $pdf endPage
                set open 0
                set slot 0
            }
        }
        if {$open} { $pdf endPage }
        return $sheetsWritten
    }

    # ------------------------------------------------------------------
    # Text that has to fit a box
    # ------------------------------------------------------------------
    #
    # "Bundesanstalt fuer Immobilienaufgaben" is wider than 70 mm. All
    # three strategies below are needed in practice, and all three measure
    # in points with getStringWidth -- never in characters. Under Tcl 8.6 a
    # character above U+FFFF counts as two, and a column width computed
    # from [string length] is wrong before anything is drawn.

    # Largest size at or below $size at which $text fits $maxW. Never goes
    # below $min, because a label nobody can read is not a solution.
    # The font name has to be passed: pdf4tcl has no getFont, and guessing
    # it from the object is not possible. Sets the font as a side effect,
    # so the caller can draw straight afterwards.
    proc fitSize {pdf font text maxW size {min 6}} {
        set cur $size
        while {1} {
            $pdf setFont $cur $font
            if {[$pdf getStringWidth $text] <= $maxW || $cur <= $min} break
            set cur [expr {$cur - 0.5}]
        }
        return $cur
    }

    # Break $text into lines no wider than $maxW, at spaces. A single word
    # that is too long stays on its own line rather than being cut -- a
    # broken postcode is worse than a wide one.
    proc wrap {pdf text maxW} {
        set lines {}
        set cur ""
        foreach word [split $text " "] {
            set try [expr {$cur eq "" ? $word : "$cur $word"}]
            if {[$pdf getStringWidth $try] <= $maxW || $cur eq ""} {
                set cur $try
            } else {
                lappend lines $cur
                set cur $word
            }
        }
        if {$cur ne ""} { lappend lines $cur }
        return $lines
    }

    # Shorten to fit, ending in an ellipsis. For fields where the exact
    # value does not matter to the reader -- a reference, a note. Never for
    # an address: half a street name is not a delivery.
    proc ellipsize {pdf text maxW {tail "\u2026"}} {
        if {[$pdf getStringWidth $text] <= $maxW} { return $text }
        set out $text
        while {[string length $out] > 1} {
            set out [string range $out 0 end-1]
            if {[$pdf getStringWidth "$out$tail"] <= $maxW} {
                return "$out$tail"
            }
        }
        return $tail
    }

    # ------------------------------------------------------------------
    # Printer calibration
    # ------------------------------------------------------------------
    #
    # Writes one sheet with a millimetre scale along the top and left edge
    # and an outline at every label position. Print it at actual size, lay
    # it on a real sheet, read off how far the grid sits from where it
    # should, and pass those two numbers as -offsetx/-offsety from then on.
    #
    # This is the difference between "the labels are slightly off" as a
    # permanent state of affairs and two numbers in a config file.
    proc calibration {pdf name} {
        set geo [sheet $name]
        $pdf startPage -paper [dict get $geo paper]
        Frames $pdf $geo

        ::pdf4tcllib::tag::artifact $pdf -type Layout
        $pdf setStrokeColor 0 0 0
        $pdf setLineWidth 0.3
        $pdf setFont 6 Helvetica
        for {set mm 0} {$mm <= 210} {incr mm 5} {
            set x [::pdf4tcllib::units::mm $mm]
            set len [expr {$mm % 10 == 0 ? 6 : 3}]
            $pdf line $x 0 $x $len
            if {$mm % 20 == 0} { $pdf text $mm -x [expr {$x + 1}] -y 12 }
        }
        for {set mm 0} {$mm <= 297} {incr mm 5} {
            set y [::pdf4tcllib::units::mm $mm]
            set len [expr {$mm % 10 == 0 ? 6 : 3}]
            $pdf line 0 $y $len $y
            if {$mm % 20 == 0} { $pdf text $mm -x 8 -y [expr {$y + 2}] }
        }
        $pdf setFont 9 Helvetica
        $pdf text "[dict get $geo desc] -- print at ACTUAL SIZE" \
                -x [::pdf4tcllib::units::mm 20] \
                -y [::pdf4tcllib::units::mm 12]
        ::pdf4tcllib::tag::artifactEnd $pdf
        $pdf endPage
        return
    }

    # Outlines for checking the alignment against a real sheet. An artifact:
    # the lines carry no meaning, and a reader announcing them would read
    # out a grid between every address.
    proc Frames {pdf geo} {
        ::pdf4tcllib::tag::artifact $pdf -type Layout
        $pdf setStrokeColor 0.8 0.8 0.8
        $pdf setLineWidth 0.25
        for {set i 0} {$i < [dict get $geo perSheet]} {incr i} {
            lassign [place $geo $i] x y
            $pdf rectangle $x $y [dict get $geo w] [dict get $geo h]
        }
        $pdf setStrokeColor 0 0 0
        ::pdf4tcllib::tag::artifactEnd $pdf
    }
}

package provide pdf4tcllabels 0.1
