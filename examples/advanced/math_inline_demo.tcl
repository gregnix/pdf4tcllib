#!/usr/bin/env tclsh
# ============================================================================
# math_inline_demo.tcl -- Demonstrates pdf4tcllib's math inline helpers
# ============================================================================
#
# Shows:
#   1. mathSymbol -- LaTeX-name -> Unicode lookup (Greek, operators, ...)
#   2. superscript -- raised, smaller (e.g. x^2)
#   3. subscript -- lowered, smaller (e.g. H_2O)
#   4. Combined: real inline-math expressions
#
# WICHTIG: Greek-Buchstaben und Math-Symbole sind ausserhalb von Helvetica's
# Charset. Wir laden TTF-Fonts via pdf4tcllib::fonts::init -- DejaVu/Liberation
# wird automatisch gefunden (Linux/Windows/macOS).
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
set libDir [file normalize [file join $scriptDir ../.. lib]]
::tcl::tm::path add $libDir

package require pdf4tcl
package require pdf4tcllib 0.2

# --- Fonts initialisieren mit CID-Mode (volles Unicode) ---
# CID-Mode bettet die kompletten TTF-Glyphen ein, kein 256-Char-Limit.
# Damit funktionieren Greek-Buchstaben (alpha, beta, ...) und
# Math-Symbole (infty, sum, int, ...) im PDF.
# Trade-off: groesseres PDF (~30-50KB statt ~5KB).
pdf4tcllib::fonts::init -cid 1

if {[pdf4tcllib::fonts::hasTtf]} {
    set fontSans     [pdf4tcllib::fonts::fontSans]
    set fontSansBold [pdf4tcllib::fonts::fontSansBold]
    puts "Using Unicode-TTF: $fontSans (Greek + Math symbols renderable)"
} else {
    set fontSans     Helvetica
    set fontSansBold Helvetica-Bold
    puts "WARNING: no Unicode TTF found -- Greek/Math symbols will show as '?'"
    puts "         Install fonts-dejavu (Linux) or DejaVuSans.ttf manually."
}

# Tk-Fenster verstecken falls wish verwendet wird
catch {wm withdraw .}

set pdf [pdf4tcl::new %AUTO% -paper a4 -compress 1]
$pdf startPage

# Helper: safeText handles non-renderable glyphs gracefully
proc out {pdf str x y} {
    pdf4tcllib::unicode::safeText $pdf $str -x $x -y $y
}

# ----------------------------------------------------------------
# Title
# ----------------------------------------------------------------
$pdf setFont 18 $fontSansBold
out $pdf "pdf4tcllib Math Helpers Demo" 100 70

# ----------------------------------------------------------------
# 1. mathSymbol -- LaTeX-Namen zu Unicode
# ----------------------------------------------------------------
$pdf setFont 12 $fontSansBold
out $pdf "1. mathSymbol -- LaTeX-Namen zu Unicode" 100 120

$pdf setFont 11 $fontSans
set y 145
foreach {label names} {
    "alpha, beta, gamma:"    "alpha beta gamma"
    "Sigma, Pi, Omega:"      "Sigma Pi Omega"
    "le, ge, ne, approx:"    "le ge ne approx"
    "infty, sum, int, sqrt:" "infty sum int sqrt"
    "cdot, times, pm, to:"   "cdot times pm to"
} {
    out $pdf $label 110 $y
    set glyphs ""
    foreach name $names {
        append glyphs [pdf4tcllib::text::mathSymbol $name] " "
    }
    out $pdf $glyphs 280 $y
    incr y 18
}

# ----------------------------------------------------------------
# 2. Superscript -- E=mc^2
# ----------------------------------------------------------------
incr y 20
$pdf setFont 12 $fontSansBold
out $pdf "2. Superscript: E=mc^2" 100 $y

incr y 25
$pdf setFont 14 $fontSans
set x 110
out $pdf "E = mc" $x $y
set x [expr {$x + [$pdf getStringWidth "E = mc"]}]
pdf4tcllib::text::superscript $pdf "2" $x $y 14 $fontSans

# Plus quadratischer Ausdruck
incr y 30
set x 110
out $pdf "ax" $x $y
set x [expr {$x + [$pdf getStringWidth "ax"]}]
set w [pdf4tcllib::text::superscript $pdf "2" $x $y 14 $fontSans]
set x [expr {$x + $w}]
out $pdf " + bx + c = 0" $x $y

# ----------------------------------------------------------------
# 3. Subscript -- H_2O, CO_2
# ----------------------------------------------------------------
incr y 40
$pdf setFont 12 $fontSansBold
out $pdf "3. Subscript: H_2O, CO_2" 100 $y

incr y 25
$pdf setFont 14 $fontSans
set x 110
out $pdf "H" $x $y
set x [expr {$x + [$pdf getStringWidth "H"]}]
set w [pdf4tcllib::text::subscript $pdf "2" $x $y 14 $fontSans]
set x [expr {$x + $w}]
out $pdf "O" $x $y

incr y 25
set x 110
out $pdf "CO" $x $y
set x [expr {$x + [$pdf getStringWidth "CO"]}]
pdf4tcllib::text::subscript $pdf "2" $x $y 14 $fontSans

# ----------------------------------------------------------------
# 4. Combined: alpha_i^2 + beta_i^2
# ----------------------------------------------------------------
incr y 40
$pdf setFont 12 $fontSansBold
out $pdf "4. Combined: alpha_i^2 + beta_i^2" 100 $y

incr y 25
$pdf setFont 14 $fontSans
set x 110
set alphaGlyph [pdf4tcllib::text::mathSymbol alpha]
set betaGlyph  [pdf4tcllib::text::mathSymbol beta]

out $pdf $alphaGlyph $x $y
set x [expr {$x + [$pdf getStringWidth $alphaGlyph]}]
set w [pdf4tcllib::text::subscript $pdf "i" $x $y 14 $fontSans]
set x [expr {$x + $w}]
set w [pdf4tcllib::text::superscript $pdf "2" $x $y 14 $fontSans]
set x [expr {$x + $w}]
out $pdf " + " $x $y
set x [expr {$x + [$pdf getStringWidth " + "]}]
out $pdf $betaGlyph $x $y
set x [expr {$x + [$pdf getStringWidth $betaGlyph]}]
set w [pdf4tcllib::text::subscript $pdf "i" $x $y 14 $fontSans]
set x [expr {$x + $w}]
pdf4tcllib::text::superscript $pdf "2" $x $y 14 $fontSans

# ----------------------------------------------------------------
# Note
# ----------------------------------------------------------------
incr y 60
$pdf setFont 10 $fontSans
out $pdf "Note: Sub/Super use 70% font size + 35%/20% baseline shift." 100 $y
incr y 14
out $pdf "Full LaTeX (fractions, roots, integrals) needs an external" 100 $y
incr y 14
out $pdf "engine like KaTeX-CLI -> SVG, embedded via image." 100 $y

set outFile [file join [pwd] math_inline_demo.pdf]
$pdf write -file $outFile
$pdf destroy

puts "Wrote: $outFile"
puts "Open with any PDF viewer to see the rendered math."
