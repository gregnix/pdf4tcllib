#!/usr/bin/env tclsh
#
# text-check.tcl -- does any TEXT end up outside the page?
#
# The gap this fills. Two checks already exist and neither sees this:
#
#     geometry-check.tcl   walks re/m/l and follows the CTM. Its own
#                          header says it: "Text. That is what
#                          layout-check.tcl is for."
#     layout-check.tcl     reads the text through pdftotext -- and
#                          pdftotext drops what lies beside the sheet.
#                          Measured: 359 of 360 words came back.
#
# So a paragraph that runs off the bottom is invisible to both, and the
# promise "the two together cover the page" does not hold there.
# Measured on writeParagraph with a long text: 71 text lines, the last one
# at y = -7.3. kon-7.3 in test_consistency.tcl does the same for one case
# inside the suite; this does it for whole files.
#
# What it does: uncompress with qpdf, walk the content streams token by
# token, keep the CTM (q, Q, cm) and the text matrices (BT, Tm, Td, TD,
# T*, TL), and take the position of every SHOWING operator (Tj, TJ, ', ").
# A baseline outside the MediaBox, beyond a tolerance, is reported.
#
# Usage:
#     tclsh tools/text-check.tcl FILE.pdf ...
#     tclsh tools/text-check.tcl -tol 5 examples/basic/pdf/
#
# Exit status is 1 when something was found, so it can gate a build.
#
# WHAT IT DOES NOT SEE, and this matters before you trust it:
#
#   - The width and height of the text. Only the baseline ORIGIN is
#     tested, because the extent needs the font metrics and this script
#     does not read fonts. A line that starts on the sheet and runs off
#     the right edge is not reported. Under-reporting on purpose:
#     a finding that is not one costs more than a missed one here,
#     because the tool is meant to be run on every build.
#   - Clipping. Text may be drawn and clipped away.
#   - Rise (Ts) and horizontal scaling (Tz). Both shift the drawn glyphs
#     against the baseline; neither moves it far enough to matter for
#     "off the sheet", and adding them would mean reading the text state
#     properly.
#   - Type 3 fonts, whose glyphs are content streams of their own.
#
# A finding is not automatically a defect -- same rule as geometry-check.
# The tool says where to look.

package require Tcl 8.6-

namespace eval ::textcheck {
    variable tol 1.0
}

# --- Matrices, same three as in geometry-check ------------------------
#
# Deliberately copied rather than shared: two scripts that both run
# standalone from tools/ are easier to hand around than a third file they
# both need. If a third user turns up, they move into a module.

proc ::textcheck::identity {} { return {1 0 0 1 0 0} }

proc ::textcheck::mmul {m n} {
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

proc ::textcheck::apply {m x y} {
    lassign $m a b c d e f
    return [list [expr {$a*$x + $c*$y + $e}] [expr {$b*$x + $d*$y + $f}]]
}

proc ::textcheck::mediaBox {text} {
    if {[regexp {/MediaBox\s*\[\s*([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)} \
            $text -> x1 y1 x2 y2]} {
        return [list $x1 $y1 $x2 $y2]
    }
    # A4 as the fallback -- stated, not silently assumed.
    return {0 0 595.28 841.89}
}

proc ::textcheck::checkFile {file} {
    variable tol
    set qdf [file join [file dirname $file] \
            "textcheck-[pid]-[file tail $file]"]
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
    set gezeigt 0
    set ctm [identity]
    set stack {}

    # Text state. Tm is the current text matrix, Tlm the line matrix that
    # Td and T* step; leading is TL.
    set tm  [identity]
    set tlm [identity]
    set leading 0

    # Token by token, for the reason geometry-check gives: a line may
    # carry two operators ("q 0.1 0 0 0.1 0 0 cm"), and a line-based
    # parser drops one of them.
    set operanden {}
    foreach tok [regexp -all -inline {\S+} $text] {
        if {[string is double -strict $tok]} {
            lappend operanden $tok
            if {[llength $operanden] > 6} {
                set operanden [lrange $operanden end-5 end]
            }
            continue
        }
        switch -- $tok {
            q { lappend stack $ctm }
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
            BT {
                set tm  [identity]
                set tlm [identity]
            }
            Tm {
                if {[llength $operanden] >= 6} {
                    set tm  [lrange $operanden end-5 end]
                    set tlm $tm
                }
            }
            TL {
                if {[llength $operanden] >= 1} {
                    set leading [lindex $operanden end]
                }
            }
            Td - TD {
                if {[llength $operanden] >= 2} {
                    lassign [lrange $operanden end-1 end] tx ty
                    if {$tok eq "TD"} { set leading [expr {-$ty}] }
                    set tlm [mmul [list 1 0 0 1 $tx $ty] $tlm]
                    set tm  $tlm
                }
            }
            T* {
                set tlm [mmul [list 1 0 0 1 0 [expr {-$leading}]] $tlm]
                set tm  $tlm
            }
            Tj - TJ - ' - \" {
                # ' and " step a line first (ISO 32000-1 table 109).
                if {$tok eq "'" || $tok eq "\""} {
                    set tlm [mmul [list 1 0 0 1 0 [expr {-$leading}]] $tlm]
                    set tm  $tlm
                }
                incr gezeigt
                lassign [apply [mmul $tm $ctm] 0 0] tx ty
                if {$tx < $px1 - $tol || $tx > $px2 + $tol ||
                        $ty < $py1 - $tol || $ty > $py2 + $tol} {
                    lappend findings [format "text  %.1f %.1f" $tx $ty]
                }
            }
        }
        set operanden {}
    }

    return [list ok $findings [list $px1 $py1 $px2 $py2] $gezeigt]
}

proc ::textcheck::main {argv} {
    variable tol
    set files {}
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set a [lindex $argv $i]
        switch -- $a {
            -tol { incr i ; set tol [lindex $argv $i] }
            -h - --help {
                puts "usage: text-check.tcl ?-tol N? FILE.pdf|DIR ..."
                return 0
            }
            default {
                if {[file isdirectory $a]} {
                    lappend files {*}[lsort [glob -nocomplain \
                            [file join $a *.pdf]]]
                } else {
                    lappend files $a
                }
            }
        }
    }
    if {![llength $files]} {
        puts stderr "text-check: no files given"
        return 2
    }
    if {![llength [auto_execok qpdf]]} {
        puts "text-check: qpdf not found -- skipped"
        return 0
    }

    set schlecht 0
    set gesamt 0
    set uebersprungen 0
    foreach f $files {
        incr gesamt
        lassign [checkFile $f] status befunde box gezeigt
        if {$status eq "error"} {
            # Eine Datei, die sich nicht oeffnen laesst -- verschluesselt,
            # kaputt --, ist kein Befund. Sie als einen zu zaehlen faerbt
            # den Lauf rot, ohne dass jemand etwas nachsehen koennte:
            # gemessen an demo_38_encrypted.pdf, das qpdf ohne Passwort
            # zurueckweist. Gemeldet ja, gezaehlt nein.
            puts [format "%-40s skipped -- %s" [file tail $f] $befunde]
            incr uebersprungen
            continue
        }
        if {[llength $befunde]} {
            incr schlecht
            lassign $box x1 y1 x2 y2
            puts [format "%-40s %d of %d baselines outside %.0fx%.0f" \
                    [file tail $f] [llength $befunde] $gezeigt \
                    [expr {$x2 - $x1}] [expr {$y2 - $y1}]]
            # At most five, then the count. A paragraph that runs off the
            # sheet produces one finding per line; sixty of them push
            # everything else out of sight.
            foreach b [lrange $befunde 0 4] { puts "    $b" }
            if {[llength $befunde] > 5} {
                puts [format "    ... and %d more" \
                        [expr {[llength $befunde] - 5}]]
            }
        }
    }
    if {$uebersprungen} {
        puts [format "%d file(s), %d with text off the page, %d skipped" \
                $gesamt $schlecht $uebersprungen]
    } else {
        puts [format "%d file(s), %d with text off the page" $gesamt $schlecht]
    }
    return [expr {$schlecht ? 1 : 0}]
}

if {[info exists argv0] && [file tail [info script]] eq [file tail $argv0]} {
    exit [::textcheck::main $argv]
}
