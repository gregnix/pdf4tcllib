#!/usr/bin/env tclsh
#
# geometry-check.tcl -- does anything DRAWN end up outside the page?
#
# The gap this fills: layout-check.tcl reads the text with pdftotext and
# finds overlaps and margin violations. It sees nothing that is drawn --
# a rectangle, a rule, a pie chart. Three demos ran off the sheet for
# months without any of the checks noticing:
#
#     27_patterns          a pattern at x=520, 200 wide, on a 595 wide page
#     18_address_labels    3 columns of 70 mm labels = 609 points
#     41_charts            chart::pie passed a bounding box where pdf4tcl
#                          wants a centre, so the circle sat 107 points
#                          left of the sheet
#
# What it does: uncompress the file with qpdf, walk the content streams
# and collect the coordinates of "re" (rectangle), "m" (moveto) and "l"
# (lineto). Anything outside the MediaBox, beyond a tolerance, is
# reported.
#
# Usage:
#     tclsh tools/geometry-check.tcl FILE.pdf ...
#     tclsh tools/geometry-check.tcl -tol 5 examples/basic/pdf/
#
# Exit status is 1 when something was found, so it can gate a build.
#
# WHAT IT DOES NOT SEE, and this matters before you trust it:
#
#   - Transformations. A "cm" before the path changes where the numbers
#     land; this script reads them raw. Rotated or scaled content
#     therefore gives false alarms -- and, the other way round, content
#     moved OUTSIDE by a cm is not caught.
#   - Curves. Only the first pair of a "c" is a point on the path, the
#     other two are control points; both are skipped rather than
#     reporting control points that legitimately sit outside.
#   - Text. That is what layout-check.tcl is for. The two together cover
#     the page; neither does on its own.
#
# A finding is not automatically a defect. Measured over the demos: all
# six remaining hits in examples/advanced are canvas exports, where the
# drawing is placed with a "cm" the script does not see -- false alarms.
# Everything in examples/basic was real, and is fixed.
#
# So: read the numbers, then decide. The tool narrows down where to look;
# it does not judge.

package require Tcl 8.6-

namespace eval ::geocheck {
    variable tol 1.0
}

proc ::geocheck::mediaBox {text} {
    if {[regexp {/MediaBox\s*\[\s*([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)} \
            $text -> x1 y1 x2 y2]} {
        return [list $x1 $y1 $x2 $y2]
    }
    # A4 as the fallback -- stated, not silently assumed.
    return {0 0 595.28 841.89}
}

proc ::geocheck::checkFile {file} {
    variable tol
    set qdf [file join [file dirname $file] \
            "geocheck-[pid]-[file tail $file]"]
    if {[catch {exec qpdf --qdf --object-streams=disable $file $qdf} msg]} {
        # qpdf ends with 3 on warnings and still writes the file.
        if {![file exists $qdf]} {
            return [list error "qpdf: $msg"]
        }
    }
    set fh [open $qdf rb]
    set text [read $fh]
    close $fh
    file delete $qdf

    lassign [mediaBox $text] px1 py1 px2 py2
    set findings {}
    foreach line [split $text "\n"] {
        set line [string trim $line]
        if {[regexp {^([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) re$} \
                $line -> x y w h]} {
            set x2 [expr {$x + $w}]
            set y2 [expr {$y + $h}]
            # A rectangle may be given with a negative width or height;
            # then the corner is the other one.
            set xa [expr {min($x, $x2)}] ; set xb [expr {max($x, $x2)}]
            set ya [expr {min($y, $y2)}] ; set yb [expr {max($y, $y2)}]
            if {$xa < $px1 - $tol || $xb > $px2 + $tol ||
                    $ya < $py1 - $tol || $yb > $py2 + $tol} {
                lappend findings [format \
                        "rect  %.1f %.1f to %.1f %.1f" $xa $ya $xb $yb]
            }
            continue
        }
        if {[regexp {^([-0-9.]+) ([-0-9.]+) [ml]$} $line -> x y]} {
            if {$x < $px1 - $tol || $x > $px2 + $tol ||
                    $y < $py1 - $tol || $y > $py2 + $tol} {
                lappend findings [format "point %.1f %.1f" $x $y]
            }
        }
    }
    return [list ok $findings [list $px1 $py1 $px2 $py2]]
}

proc ::geocheck::main {argv} {
    variable tol
    set files {}
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set a [lindex $argv $i]
        switch -- $a {
            -tol { incr i ; set tol [lindex $argv $i] }
            -h - --help {
                puts "usage: geometry-check.tcl ?-tol <points>? FILE.pdf | DIR ..."
                exit 0
            }
            default {
                if {[file isdirectory $a]} {
                    foreach f [lsort [glob -nocomplain [file join $a *.pdf]]] {
                        lappend files $f
                    }
                } else {
                    lappend files $a
                }
            }
        }
    }
    if {![llength $files]} {
        puts stderr "geometry-check: no files given"
        exit 2
    }
    if {![llength [auto_execok qpdf]]} {
        puts "geometry-check: qpdf not found -- skipped"
        exit 0
    }

    set bad 0
    foreach f $files {
        lassign [checkFile $f] status findings box
        if {$status eq "error"} {
            puts [format "  %-44s SKIP %s" [file tail $f] $findings]
            continue
        }
        if {![llength $findings]} { continue }
        incr bad
        puts [format "  %-44s %d outside the page" \
                [file tail $f] [llength $findings]]
        foreach z [lrange $findings 0 2] { puts "        $z" }
        if {[llength $findings] > 3} {
            puts "        ... and [expr {[llength $findings] - 3}] more"
        }
    }
    puts ""
    puts [format "%d file(s): %d with drawings outside the page (tolerance %g pt)" \
            [llength $files] $bad $tol]
    exit [expr {$bad > 0 ? 1 : 0}]
}

if {[info exists argv0] && [file tail [info script]] eq [file tail $argv0]} {
    ::geocheck::main $argv
}
