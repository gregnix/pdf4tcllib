#!/usr/bin/env tclsh
# ============================================================================
# math_formula_demo.tcl
# ----------------------------------------------------------------------------
# Portierung von Arjen Markus' "MathFormula" (Tcler's Wiki 2002-2007) auf
# pdf4tcl-basierte PDF-Ausgabe statt Tk-Canvas.
#
# Original: https://wiki.tcl-lang.org/page/Rendering+mathematical+formulae
#
# Was anders ist:
#   - Output: PDF (skalierbar, druckbar) statt Canvas
#   - Keine Tk-Dependency -- laeuft headless (tclsh, kein wish)
#   - Symbol-Namen: LaTeX-Stil (alpha, beta, ...) statt CAPS (ALPHA, BETA)
#   - Fix fuer Arjen's Tippfehler: PI/SIGMA/TAU usw. (waren Cyrillic-CPs)
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
set libDir [file normalize [file join $scriptDir ../.. lib]]
::tcl::tm::path add $libDir

package require pdf4tcl
package require pdf4tcllib 0.2

# CID-Mode noetig fuer Greek + Math-Symbole
pdf4tcllib::fonts::init -cid 1

if {[pdf4tcllib::fonts::hasTtf]} {
    set sansFont [pdf4tcllib::fonts::fontSans]
    set sansBold [pdf4tcllib::fonts::fontSansBold]
} else {
    set sansFont Helvetica
    set sansBold Helvetica-Bold
}

catch {wm withdraw .}

set pdf [pdf4tcl::new %AUTO% -paper a4 -compress 1]
$pdf startPage

# Title
$pdf setFont 16 $sansBold
$pdf text "Mathematical Formulae -- PDF Edition" -x 100 -y 60
$pdf setFont 10 $sansFont
$pdf text "Portierung von Arjen Markus' Canvas-Renderer auf pdf4tcl" \
    -x 100 -y 80

# Helper: Formel mit Label
proc renderLabel {pdf y label formula args} {
    global sansFont sansBold
    # Label (links)
    $pdf setFont 10 $sansFont
    $pdf text $label -x 100 -y $y
    # Formel (rechts vom Label)
    pdf4tcllib::math::renderFormula $pdf 340 $y $formula -size 12 \
        -font $sansFont {*}$args
}

# ----------------------------------------------------------------
# Wiki-Beispiele (Original-Tokens)
# ----------------------------------------------------------------
set y 130

renderLabel $pdf $y "1. Mit Sub/Super:" \
    "Not ~ p ` erfect ~ yet, ~ but ..."
incr y 28

renderLabel $pdf $y "2. Summe + Integral mit Limits:" \
    "SUM from i=0 to infty ~ A _ i ~ = ~ INT from 0 to pi cos ^ 2 x dx"
incr y 28

renderLabel $pdf $y "3. Exponential:" \
    "0.1 = e ^ -kT90"
incr y 28

renderLabel $pdf $y "4. Polynom:" \
    "f(x) = x ^ 3 - x ^ 2 + x - 1"
incr y 28

renderLabel $pdf $y "5. Trigonometrie:" \
    "h(t) = cos( omega t - alpha )"
incr y 28

renderLabel $pdf $y "6. Partielle Differentialgleichung:" \
    "partial phi / partial t = D nabla ^ 2 phi"
incr y 28

renderLabel $pdf $y "7. Produkt:" \
    "PROD (1-1/n) ^ n"
incr y 28

renderLabel $pdf $y "8. Quantoren:" \
    "forall x in Z ~ exists y in Z ~ x ge y"
incr y 28

# Weitere Beispiele die im Wiki nicht waren
incr y 20
$pdf setFont 11 $sansBold
$pdf text "Zusaetzliche Beispiele:" -x 100 -y $y
incr y 20

renderLabel $pdf $y "9. Quadratische Loesungsformel:" \
    "x = ( -b pm sqrt ( b ^ 2 - 4ac ) ) / 2a"
incr y 28

renderLabel $pdf $y "10. Einstein:" \
    "E = mc ^ 2"
incr y 28

renderLabel $pdf $y "11. Pythagoras:" \
    "a ^ 2 + b ^ 2 = c ^ 2"
incr y 28

renderLabel $pdf $y "12. Eulersche Identitaet:" \
    "e ^ ( i pi ) + 1 = 0"
incr y 28

renderLabel $pdf $y "13. Wasserstoff in Wasser:" \
    "2 H _ 2 + O _ 2 rightarrow 2 H _ 2 O"
incr y 28

renderLabel $pdf $y "14. Mengen:" \
    "A cap B subset A cup B"
incr y 28

# Notes
incr y 30
$pdf setFont 10 $sansFont
$pdf text "Notation:" -x 100 -y $y
incr y 14
$pdf text "  ^  Superscript    _  Subscript    ~  forced space" -x 110 -y $y
incr y 14
$pdf text "  alpha,beta,...  Greek letters    SUM,INT,PROD  big operators" \
    -x 110 -y $y
incr y 14
$pdf text "  from...to...    Limits unter/ueber SUM/INT/PROD" \
    -x 110 -y $y
incr y 14
$pdf text "  cdot,times,le,ge,infty,sqrt,nabla,partial,forall,exists,..." \
    -x 110 -y $y

set outFile [file join [pwd] math_formula_demo.pdf]
$pdf write -file $outFile
$pdf destroy

puts "Wrote: $outFile"
