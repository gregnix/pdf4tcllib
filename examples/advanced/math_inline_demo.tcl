#!/usr/bin/env tclsh
# math_inline_demo.tcl -- Demonstrates pdf4tcllib's math inline helpers
#
# Shows:
#   1. mathSymbol -- LaTeX-name -> Unicode lookup
#   2. superscript -- raised, smaller (e.g. x^2)
#   3. subscript -- lowered, smaller (e.g. H_2O)
#   4. Combined: a real inline-math line in a paragraph

set thisDir [file dirname [file normalize [info script]]]
set libDir  [file normalize [file join $thisDir .. lib]]
::tcl::tm::path add $libDir

package require pdf4tcl
package require pdf4tcllib 0.2

set pdf [pdf4tcl::new %AUTO% -paper a4 -compress 1]
$pdf startPage

# Setup
$pdf setFont 18 Helvetica
$pdf text "pdf4tcllib Math Helpers Demo" -x 100 -y 70

# ----------------------------------------------------------------
# 1. mathSymbol -- haeufige Greek + Math-Symbole
# ----------------------------------------------------------------
$pdf setFont 12 Helvetica
$pdf text "1. mathSymbol -- LaTeX-Namen zu Unicode" -x 100 -y 120

$pdf setFont 11 Helvetica
set y 145
foreach {label sym} {
    "alpha, beta, gamma:"    "alpha beta gamma"
    "Sigma, Pi, Omega:"      "Sigma Pi Omega"
    "le, ge, ne, approx:"    "le ge ne approx"
    "infty, sum, int, sqrt:" "infty sum int sqrt"
    "cdot, times, pm, to:"   "cdot times pm to"
} {
    set out ""
    foreach name $sym {
        append out [pdf4tcllib::text::mathSymbol $name] " "
    }
    $pdf text $label -x 110 -y $y
    $pdf text $out   -x 280 -y $y
    incr y 18
}

# ----------------------------------------------------------------
# 2. Superscript -- E=mc^2
# ----------------------------------------------------------------
incr y 20
$pdf setFont 12 Helvetica
$pdf text "2. Superscript: E=mc^2" -x 100 -y $y

incr y 25
$pdf setFont 14 Helvetica
set x 110
$pdf text "E = mc" -x $x -y $y
set x [expr {$x + [$pdf getStringWidth "E = mc"]}]
pdf4tcllib::text::superscript $pdf "2" $x $y 14 Helvetica

# Plus ein quadratischer Ausdruck
incr y 30
set x 110
$pdf text "ax" -x $x -y $y
set x [expr {$x + [$pdf getStringWidth "ax"]}]
set w [pdf4tcllib::text::superscript $pdf "2" $x $y 14 Helvetica]
set x [expr {$x + $w}]
$pdf text " + bx + c = 0" -x $x -y $y

# ----------------------------------------------------------------
# 3. Subscript -- H_2O, CO_2
# ----------------------------------------------------------------
incr y 40
$pdf setFont 12 Helvetica
$pdf text "3. Subscript: H_2O, CO_2" -x 100 -y $y

incr y 25
$pdf setFont 14 Helvetica
set x 110
$pdf text "H" -x $x -y $y
set x [expr {$x + [$pdf getStringWidth "H"]}]
set w [pdf4tcllib::text::subscript $pdf "2" $x $y 14 Helvetica]
set x [expr {$x + $w}]
$pdf text "O" -x $x -y $y

incr y 25
set x 110
$pdf text "CO" -x $x -y $y
set x [expr {$x + [$pdf getStringWidth "CO"]}]
pdf4tcllib::text::subscript $pdf "2" $x $y 14 Helvetica

# ----------------------------------------------------------------
# 4. Combined -- griechisch + super + sub
# ----------------------------------------------------------------
incr y 40
$pdf setFont 12 Helvetica
$pdf text "4. Combined: alpha_i^2 + beta_i^2" -x 100 -y $y

incr y 25
$pdf setFont 14 Helvetica
set x 110
# alpha
$pdf text [pdf4tcllib::text::mathSymbol alpha] -x $x -y $y
set x [expr {$x + [$pdf getStringWidth [pdf4tcllib::text::mathSymbol alpha]]}]
# subscript i
set w [pdf4tcllib::text::subscript $pdf "i" $x $y 14 Helvetica]
set x [expr {$x + $w}]
# superscript 2
set w [pdf4tcllib::text::superscript $pdf "2" $x $y 14 Helvetica]
set x [expr {$x + $w}]
# " + "
$pdf text " + " -x $x -y $y
set x [expr {$x + [$pdf getStringWidth " + "]}]
# beta
$pdf text [pdf4tcllib::text::mathSymbol beta] -x $x -y $y
set x [expr {$x + [$pdf getStringWidth [pdf4tcllib::text::mathSymbol beta]]}]
# subscript i
set w [pdf4tcllib::text::subscript $pdf "i" $x $y 14 Helvetica]
set x [expr {$x + $w}]
# superscript 2
pdf4tcllib::text::superscript $pdf "2" $x $y 14 Helvetica

# ----------------------------------------------------------------
# Note
# ----------------------------------------------------------------
incr y 80
$pdf setFont 10 Helvetica
$pdf text "Note: Sub/Super use 70% font size + 35%/20% baseline shift." \
    -x 100 -y $y
incr y 14
$pdf text "Full LaTeX (fractions, roots, integrals) needs an external" \
    -x 100 -y $y
incr y 14
$pdf text "engine like KaTeX-CLI -> SVG, embedded via image." -x 100 -y $y

set out [file join [pwd] math_inline_demo.pdf]
$pdf write -file $out
$pdf destroy

puts "Wrote: $out"
puts "Open with any PDF viewer to see the rendered math."
