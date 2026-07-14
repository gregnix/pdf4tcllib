# test_math.tcl -- Tests fuer die backend-neutrale LaTeX-Engine
# (pdf4tcllib::math seit 0.5)
#
# Die Engine spricht nur noch mit einem Backend: drei Operationen (width,
# text, line). Getestet wird deshalb dreifach:
#   A) PDF-Backend        -- das bisherige Verhalten, unveraendert
#   B) Aufzeichnungs-Backend -- protokolliert die Primitiven, ohne Tk und ohne
#                              PDF: so laesst sich pruefen, WAS die Engine
#                              zeichnet, nicht nur dass es nicht kracht
#   C) Canvas-Backend     -- nur wenn Tk und ein Display da sind

package require tcltest
namespace import ::tcltest::*

# The engine under test lives in ../lib. Without this the suite silently ran
# against whatever pdf4tcllib happened to be on the tm path -- an older one has
# no renderLatexOn, and all 13 tests failed with "invalid command name".
set testDir [file dirname [file normalize [info script]]]
catch {tcl::tm::path add [file normalize [file join $testDir .. lib]]}
package require pdf4tcllib 0.5

set hasPdf4tcl [expr {![catch {package require pdf4tcl}]}]
set hasTk      [expr {![catch {package require Tk}]}]
testConstraint pdf4tcl $hasPdf4tcl
testConstraint tk      $hasTk

# ============================================================
# B) Aufzeichnungs-Backend -- braucht weder PDF noch Tk
# ============================================================

# Ein Backend ist ein Command-Prefix mit drei Operationen. Mehr verlangt die
# Engine nicht -- genau das macht sie backend-neutral.
proc recBackend {logVar} {
    return [list ::recBackendCmd $logVar]
}
proc recBackendCmd {logVar op args} {
    upvar #0 $logVar log
    switch -- $op {
        width {
            lassign $args font size text
            # 0.5 * size pro Zeichen: deterministisch, damit die Tests rechnen
            # koennen, ohne von echten Font-Metriken abzuhaengen.
            lappend log [list width $size $text]
            return [expr {0.5 * $size * [string length $text]}]
        }
        text {
            lassign $args font size x y text
            lappend log [list text $size $x $y $text]
            return
        }
        line {
            lassign $args x1 y1 x2 y2 lw
            lappend log [list line $x1 $y1 $x2 $y2 $lw]
            return
        }
    }
    return -code error "unknown op $op"
}

test math-backend-plain-text "einfache Formel: nur text-Ops, kein line" -body {
    set ::log {}
    ::pdf4tcllib::math::renderLatexOn [recBackend ::log] 0 0 "a+b" -size 10
    set kinds {}
    foreach e $::log {
        set k [lindex $e 0]
        if {$k ne "width" && $k ni $kinds} { lappend kinds $k }
    }
    set kinds
} -result {text}

test math-backend-frac-draws-rule "\\frac zeichnet einen Bruchstrich" -body {
    set ::log {}
    ::pdf4tcllib::math::renderLatexOn [recBackend ::log] 0 0 {\frac{a}{b}} -size 10
    set lines 0
    foreach e $::log {
        if {[lindex $e 0] eq "line"} { incr lines }
    }
    expr {$lines == 1}
} -result 1

test math-backend-frac-stacks "Zaehler ueber, Nenner unter dem Strich" -body {
    set ::log {}
    ::pdf4tcllib::math::renderLatexOn [recBackend ::log] 0 100 {\frac{a}{b}} -size 10
    set ya ""; set yb ""; set yLine ""
    foreach e $::log {
        switch -- [lindex $e 0] {
            text { if {[lindex $e 4] eq "a"} { set ya [lindex $e 3] }
                   if {[lindex $e 4] eq "b"} { set yb [lindex $e 3] } }
            line { set yLine [lindex $e 2] }
        }
    }
    # y waechst nach unten: Zaehler hat kleineres y als der Strich, Nenner
    # ein groesseres.
    expr {$ya < $yLine && $yb > $yLine}
} -result 1

test math-backend-script-size "Exponent wird kleiner gesetzt als die Basis" -body {
    set ::log {}
    ::pdf4tcllib::math::renderLatexOn [recBackend ::log] 0 0 {x^2} -size 12
    set sizeX ""; set size2 ""
    foreach e $::log {
        if {[lindex $e 0] ne "text"} continue
        if {[lindex $e 4] eq "x"} { set sizeX [lindex $e 1] }
        if {[lindex $e 4] eq "2"} { set size2 [lindex $e 1] }
    }
    expr {$size2 < $sizeX}
} -result 1

test math-backend-measure-agrees "measureLatexOn stimmt mit dem Vorschub ueberein" -body {
    set ::log {}
    set be [recBackend ::log]
    lassign [::pdf4tcllib::math::measureLatexOn $be "abc" -size 10] w h d
    set endX [::pdf4tcllib::math::renderLatexOn $be 0 0 "abc" -size 10]
    # gemessene Breite == gezeichneter Vorschub
    expr {abs($w - $endX) < 0.001 && $w > 0}
} -result 1

test math-backend-unknown-op "Backend meldet unbekannte Operation" -body {
    catch {::pdf4tcllib::math::_pdfBackend dummy bogus} err opts
    dict get $opts -errorcode
} -result {PDF4TCLLIB MATH BACKEND}

# ============================================================
# A) PDF-Backend -- das alte Verhalten muss unveraendert sein
# ============================================================

test math-pdf-measure "measureLatex liefert {w h d}" -constraints pdf4tcl -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set m [::pdf4tcllib::math::measureLatex $pdf "E = mc^2" -size 11]
    $pdf destroy
    list [llength $m] [expr {[lindex $m 0] > 0}]
} -result {3 1}

test math-pdf-render "renderLatex zeichnet und liefert den Vorschub" -constraints pdf4tcl -body {
    set out [file join [::tcltest::temporaryDirectory] math-pdf.pdf]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -file $out]
    $pdf startPage
    set endX [::pdf4tcllib::math::renderLatex $pdf 50 100 {\frac{a}{b}} -size 11]
    $pdf finish
    $pdf destroy
    set ok [expr {$endX > 50 && [file exists $out] && [file size $out] > 0}]
    catch {file delete $out}
    set ok
} -result 1

test math-pdf-backend-equivalence "pdfBackend == klassischer Aufruf" -constraints pdf4tcl -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set a [::pdf4tcllib::math::measureLatex $pdf "x^2 + y^2" -size 11]
    set b [::pdf4tcllib::math::measureLatexOn \
        [::pdf4tcllib::math::pdfBackend $pdf] "x^2 + y^2" -size 11 \
        -font [::pdf4tcllib::math::_defaultPdfFont]]
    $pdf destroy
    expr {$a eq $b}
} -result 1

# ============================================================
# C) Canvas-Backend -- Tk
# ============================================================

test math-canvas-draws-items "Formel landet als Canvas-Items" -constraints tk -body {
    set c [canvas .cmath1]
    set be [::pdf4tcllib::math::canvasBackend $c -tags formula]
    ::pdf4tcllib::math::renderLatexOn $be 20 40 {\frac{a}{b}} -size 12
    set n [llength [$c find withtag formula]]
    destroy $c
    # mindestens: Zaehler, Nenner, Bruchstrich
    expr {$n >= 3}
} -result 1

test math-canvas-line-for-frac "der Bruchstrich ist ein line-Item" -constraints tk -body {
    set c [canvas .cmath2]
    set be [::pdf4tcllib::math::canvasBackend $c -tags f]
    ::pdf4tcllib::math::renderLatexOn $be 20 40 {\frac{a}{b}} -size 12
    set types {}
    foreach id [$c find withtag f] { lappend types [$c type $id] }
    destroy $c
    expr {"line" in $types && "text" in $types}
} -result 1

test math-canvas-measure-positive "measureLatexOn misst auf dem Canvas" -constraints tk -body {
    set c [canvas .cmath3]
    set be [::pdf4tcllib::math::canvasBackend $c]
    lassign [::pdf4tcllib::math::measureLatexOn $be "E = mc^2" -size 12] w h d
    destroy $c
    expr {$w > 0 && $h > 0}
} -result 1

test math-canvas-tags-delete "die Formel ist als Einheit loeschbar" -constraints tk -body {
    set c [canvas .cmath4]
    set be [::pdf4tcllib::math::canvasBackend $c -tags formula]
    ::pdf4tcllib::math::renderLatexOn $be 10 30 "a+b" -size 12
    $c delete formula
    set n [llength [$c find all]]
    destroy $c
    set n
} -result 0

cleanupTests
