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
#   - Curves in full. Only the first pair of a "c" is a point on the
#     path, the other two are control points; both are skipped rather
#     than reporting control points that legitimately sit outside.
#   - Clipping. A path may be drawn and then clipped away; this script
#     sees the path, not what remains visible.
#   - Text. That is what layout-check.tcl is for. The two together cover
#     the page; neither does on its own.
#
# TRANSFORMATIONS ARE FOLLOWED (since the second version), and that
# turned six "false alarms" into two real defects.
#
# The first version read the numbers raw and reported every canvas
# export -- six hits in examples/advanced, all written off as false
# alarms because the drawing is placed with a "cm". Six of those at every
# run is worse than no check: one gets used to them, and then a real
# finding goes unnoticed too.
#
# So the script now keeps the current transformation matrix, following
# "q", "Q" and "cm", and transforms every point before comparing. Of the
# six, four really were false alarms -- measured on demo_08_canvas.pdf,
# "1 0 0 -1 47 767 cm" with a path from 0,0 to 500,600 looks off the page
# raw and sits on it transformed. The other two were defects nobody had
# looked at:
#
#   55_canvas_items_matrix  the table was 560 pt wide from x=42.5, so it
#                           ended at 602.5 on a 595 pt page
#   51_canvas_pdf_vs_ps     page 2 stepped y the wrong way under
#                           -orient true, so the text ran off the top --
#                           the embedded canvas ended up 179 pt above the
#                           sheet
#
# Reading tokens, not lines. demo_50 contains "q 0.1 0 0 0.1 0 0 cm" --
# two operators on one line. A line-based parser missed both, dropped the
# 0.1 scale and reported 93 findings that were none. That one nearly went
# down as "canvas exports, known false alarm" too.
#
# A finding is still not automatically a defect. Read the numbers, then
# decide. The tool narrows down where to look; it does not judge.

package require Tcl 8.6-

namespace eval ::geocheck {
    variable tol 1.0
}

# --- Die aktuelle Transformationsmatrix -------------------------------
#
# PDF fuehrt sie als {a b c d e f}:
#
#     x' = a*x + c*y + e
#     y' = b*x + d*y + f
#
# "cm" multipliziert VON LINKS an die bestehende Matrix, "q" legt sie auf
# einen Stapel, "Q" holt sie zurueck.

proc ::geocheck::identity {} { return {1 0 0 1 0 0} }

proc ::geocheck::mmul {m n} {
    lassign $m a1 b1 c1 d1 e1 f1
    lassign $n a2 b2 c2 d2 e2 f2
    return [list \
        [expr {$a1*$a2 + $b1*$c2}] \
        [expr {$a1*$b2 + $b1*$d2}] \
        [expr {$c1*$a2 + $d1*$c2}] \
        [expr {$c1*$b2 + $d1*$d2}] \
        [expr {$e1*$a2 + $f1*$c2 + $e2}] \
        [expr {$e1*$b2 + $f1*$d2 + $f2}]]
}

proc ::geocheck::apply {m x y} {
    lassign $m a b c d e f
    return [list [expr {$a*$x + $c*$y + $e}] [expr {$b*$x + $d*$y + $f}]]
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
    set ctm [identity]
    set stack {}

    # TOKENWEISE, nicht zeilenweise.
    #
    # Die erste Fassung verlangte eine Zeile, die genau "q" lautet oder
    # genau auf "cm" endet. In demo_50 steht aber
    #
    #     q 0.1 0 0 0.1 0 0 cm
    #
    # -- zwei Operatoren in einer Zeile. Beide wurden uebersehen, die
    # Skalierung um 0.1 fiel aus, und die Koordinaten kamen als 6229
    # statt 622,9 heraus: 93 Befunde, die keine waren. Ich haette sie
    # ohne Nachsehen als Fehlalarm abgetan.
    set operanden {}
    foreach tok [regexp -all -inline {\S+} $text] {
        if {[string is double -strict $tok]} {
            lappend operanden $tok
            # Mehr als sechs braucht keiner der Operatoren, die hier
            # zaehlen; laenger werden zu lassen kostet nur Speicher.
            if {[llength $operanden] > 6} {
                set operanden [lrange $operanden end-5 end]
            }
            continue
        }
        switch -- $tok {
            q {
                lappend stack $ctm
            }
            Q {
                if {[llength $stack]} {
                    set ctm [lindex $stack end]
                    set stack [lrange $stack 0 end-1]
                }
            }
            cm {
                if {[llength $operanden] >= 6} {
                    set ctm [mmul [lrange $operanden end-5 end] $ctm]
                }
            }
            re {
                if {[llength $operanden] >= 4} {
                    lassign [lrange $operanden end-3 end] x y w h
                    set xs {} ; set ys {}
                    foreach {ex ey} [list $x $y [expr {$x+$w}] $y \
                            [expr {$x+$w}] [expr {$y+$h}] \
                            $x [expr {$y+$h}]] {
                        lassign [apply $ctm $ex $ey] tx ty
                        lappend xs $tx ; lappend ys $ty
                    }
                    set xa [::tcl::mathfunc::min {*}$xs]
                    set xb [::tcl::mathfunc::max {*}$xs]
                    set ya [::tcl::mathfunc::min {*}$ys]
                    set yb [::tcl::mathfunc::max {*}$ys]
                    if {$xa < $px1 - $tol || $xb > $px2 + $tol ||
                            $ya < $py1 - $tol || $yb > $py2 + $tol} {
                        lappend findings [format \
                                "rect  %.1f %.1f to %.1f %.1f" \
                                $xa $ya $xb $yb]
                    }
                }
            }
            m - l {
                if {[llength $operanden] >= 2} {
                    lassign [lrange $operanden end-1 end] x y
                    lassign [apply $ctm $x $y] tx ty
                    if {$tx < $px1 - $tol || $tx > $px2 + $tol ||
                            $ty < $py1 - $tol || $ty > $py2 + $tol} {
                        lappend findings [format "point %.1f %.1f" $tx $ty]
                    }
                }
            }
        }
        set operanden {}
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
