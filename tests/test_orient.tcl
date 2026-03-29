# test_orient.tcl -- Tests fuer orient-aware Koordinaten in pdf4tcllib
#
# Testet dass page::context, _advance, header/footer/number
# korrekte y-Werte fuer beide orient-Modi liefern.
#
package require tcltest
namespace import ::tcltest::*

# ============================================================
# page::context -- orient true (y grows down)
# ============================================================

test orient-ctx-true-top "orient true: top = margin (kleiner Wert, oben)" -body {
    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
    set top [dict get $ctx top]
    set margin [dict get $ctx margin]
    expr {abs($top - $margin) < 0.01}
} -result 1

test orient-ctx-true-bottom "orient true: bottom = page_h - margin (grosser Wert)" -body {
    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
    set bottom [dict get $ctx bottom]
    set ph     [dict get $ctx page_h]
    set margin [dict get $ctx margin]
    expr {abs($bottom - ($ph - $margin)) < 0.01}
} -result 1

test orient-ctx-true-topltbottom "orient true: top < bottom" -body {
    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
    expr {[dict get $ctx top] < [dict get $ctx bottom]}
} -result 1

# ============================================================
# page::context -- orient false (y grows up)
# ============================================================

test orient-ctx-false-top "orient false: top = page_h - margin (grosser Wert)" -body {
    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient false]
    set top    [dict get $ctx top]
    set ph     [dict get $ctx page_h]
    set margin [dict get $ctx margin]
    expr {abs($top - ($ph - $margin)) < 0.01}
} -result 1

test orient-ctx-false-bottom "orient false: bottom = margin (kleiner Wert)" -body {
    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient false]
    set bottom [dict get $ctx bottom]
    set margin [dict get $ctx margin]
    expr {abs($bottom - $margin) < 0.01}
} -result 1

test orient-ctx-false-topgtbottom "orient false: top > bottom" -body {
    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient false]
    expr {[dict get $ctx top] > [dict get $ctx bottom]}
} -result 1

# ============================================================
# page::context -- default ist orient true
# ============================================================

test orient-ctx-default "Default orient = true (top < bottom)" -body {
    set ctx [pdf4tcllib::page::context a4]
    expr {[dict get $ctx top] < [dict get $ctx bottom]}
} -result 1

test orient-ctx-default-orient "Default orient key = true" -body {
    set ctx [pdf4tcllib::page::context a4]
    dict get $ctx orient
} -result true

# ============================================================
# page::_advance -- y-Schrittmacher
# ============================================================

test advance-true-positive "orient true: y nimmt zu" -body {
    set ctx [pdf4tcllib::page::context a4 -orient true]
    set y 100
    pdf4tcllib::page::_advance $ctx y 20
    set y
} -result 120

test advance-true-zero "orient true: step=0 aendert y nicht" -body {
    set ctx [pdf4tcllib::page::context a4 -orient true]
    set y 100
    pdf4tcllib::page::_advance $ctx y 0
    set y
} -result 100

test advance-false-negative "orient false: y nimmt ab" -body {
    set ctx [pdf4tcllib::page::context a4 -orient false]
    set y 700
    pdf4tcllib::page::_advance $ctx y 20
    set y
} -result 680

test advance-false-zero "orient false: step=0 aendert y nicht" -body {
    set ctx [pdf4tcllib::page::context a4 -orient false]
    set y 700
    pdf4tcllib::page::_advance $ctx y 0
    set y
} -result 700

test advance-cumulative "Mehrere _advance kumulieren korrekt" -body {
    set ctx [pdf4tcllib::page::context a4 -orient true]
    set y 50
    pdf4tcllib::page::_advance $ctx y 10
    pdf4tcllib::page::_advance $ctx y 20
    pdf4tcllib::page::_advance $ctx y 5
    set y
} -result 85

# ============================================================
# Symmetrie: gleicher Abstand, beide Modi
# ============================================================

test orient-symmetry "Orient true/false: gleicher Abstand vom Rand" -body {
    set ctxT [pdf4tcllib::page::context a4 -margin 25 -orient true]
    set ctxF [pdf4tcllib::page::context a4 -margin 25 -orient false]
    # top-Abstand vom physischen Seitenanfang:
    # orient true:  top = margin  -> Abstand = top
    # orient false: top = ph - margin -> Abstand = ph - top = margin
    set marginT [dict get $ctxT margin]
    set marginF [dict get $ctxF margin]
    expr {abs($marginT - $marginF) < 0.01}
} -result 1

test orient-SY-matches-top "SY == top in beiden Modi" -body {
    set ctxT [pdf4tcllib::page::context a4 -orient true]
    set ctxF [pdf4tcllib::page::context a4 -orient false]
    set ok1 [expr {abs([dict get $ctxT SY] - [dict get $ctxT top]) < 0.01}]
    set ok2 [expr {abs([dict get $ctxF SY] - [dict get $ctxF top]) < 0.01}]
    expr {$ok1 && $ok2}
} -result 1

# ============================================================
# page::lineheight -- orientierungsunabhaengig
# ============================================================

test lh-orient-independent "lineheight ist orientierungsunabhaengig" -body {
    set lhT [pdf4tcllib::page::lineheight 12]
    set lhF [pdf4tcllib::page::lineheight 12]
    expr {$lhT == $lhF}
} -result 1

cleanupTests
