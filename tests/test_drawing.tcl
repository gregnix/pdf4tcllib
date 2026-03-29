# test_drawing.tcl -- Tests fuer pdf4tcllib::drawing
package require tcltest
namespace import ::tcltest::*

# ============================================================
# drawing::interpolate -- Farbinterpolation
# ============================================================

test draw-interp-start "t=0 -> Farbe 1" -body {
    pdf4tcllib::drawing::interpolate {1.0 0.0 0.0} {0.0 0.0 1.0} 0.0
} -result {1.0 0.0 0.0}

test draw-interp-end "t=1 -> Farbe 2" -body {
    pdf4tcllib::drawing::interpolate {1.0 0.0 0.0} {0.0 0.0 1.0} 1.0
} -result {0.0 0.0 1.0}

test draw-interp-mid "t=0.5 -> Mitte" -body {
    set c [pdf4tcllib::drawing::interpolate {1.0 0.0 0.0} {0.0 0.0 1.0} 0.5]
    list [format "%.1f" [lindex $c 0]] [format "%.1f" [lindex $c 1]] [format "%.1f" [lindex $c 2]]
} -result {0.5 0.0 0.5}

test draw-interp-quarter "t=0.25" -body {
    set c [pdf4tcllib::drawing::interpolate {0.0 0.0 0.0} {1.0 1.0 1.0} 0.25]
    list [format "%.2f" [lindex $c 0]] [format "%.2f" [lindex $c 1]] [format "%.2f" [lindex $c 2]]
} -result {0.25 0.25 0.25}

test draw-interp-same "Gleiche Farben -> unveraendert" -body {
    set c [pdf4tcllib::drawing::interpolate {0.5 0.5 0.5} {0.5 0.5 0.5} 0.7]
    list [format "%.1f" [lindex $c 0]] [format "%.1f" [lindex $c 1]] [format "%.1f" [lindex $c 2]]
} -result {0.5 0.5 0.5}

# ============================================================
# drawing::_arcPoints -- Kreisbogen-Punkte
# ============================================================

test draw-arc-count "90-Grad-Bogen mit 4 Segmenten -> 10 Koordinaten" -body {
    set pts {}
    pdf4tcllib::drawing::_arcPoints pts 0 0 100 0 90 4
    # 5 Punkte * 2 Koordinaten = 10
    llength $pts
} -result 10

test draw-arc-start "Startpunkt bei 0 Grad = (r, 0)" -body {
    set pts {}
    pdf4tcllib::drawing::_arcPoints pts 0 0 100 0 90 4
    set x [format "%.0f" [lindex $pts 0]]
    set y [format "%.0f" [lindex $pts 1]]
    list $x $y
} -result {100 0}

test draw-arc-end90 "Endpunkt bei 90 Grad = (0, r)" -body {
    set pts {}
    pdf4tcllib::drawing::_arcPoints pts 0 0 100 0 90 4
    set x [format "%.0f" [lindex $pts end-1]]
    set y [format "%.0f" [lindex $pts end]]
    list $x $y
} -result {0 100}

test draw-arc-full "360-Grad-Kreis: Start ~= Ende" -body {
    set pts {}
    pdf4tcllib::drawing::_arcPoints pts 50 50 100 0 360 36
    set x0 [lindex $pts 0]
    set y0 [lindex $pts 1]
    set xn [lindex $pts end-1]
    set yn [lindex $pts end]
    set dx [expr {abs($xn - $x0)}]
    set dy [expr {abs($yn - $y0)}]
    expr {$dx < 0.1 && $dy < 0.1}
} -result 1

test draw-arc-center "Offset Center: Punkte verschoben" -body {
    set pts {}
    pdf4tcllib::drawing::_arcPoints pts 100 200 50 0 0 1
    set x [format "%.0f" [lindex $pts 0]]
    set y [format "%.0f" [lindex $pts 1]]
    # 0 Grad -> (cx + r, cy) = (150, 200)
    list $x $y
} -result {150 200}

cleanupTests
