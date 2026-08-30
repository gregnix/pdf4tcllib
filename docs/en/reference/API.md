# pdf4tcllib -- API Reference

pdf4tcllib extends pdf4tcl with Unicode handling, emoji fallbacks, page context
management, text wrapping, simplified tables, and form layout.
Distributed as a single `.tm` file (3483 lines).

## Overview

While pdf4tcl operates at the level of lines, text and coordinates, pdf4tcllib
provides a layer above: page context with margins, Unicode-safe text output,
automatic line wrapping, and high-level tables. The library solves problems
that recur in every PDF project.

## Installation

```tcl
# As a .tm module
tcl::tm::path add /path/to/lib
package require pdf4tcllib

# Or in vendors/tm/ (mdstack, mdhelp4)
tcl::tm::path add vendors/tm
package require pdf4tcllib
```

Dependency: pdf4tcl (in `vendors/pkg/` or system-wide).

## Module overview

| Namespace | Purpose |
|---|---|
| fonts   | Font management: TTF search, fallback, accessor procs, setFont, CID-mode |
| page    | Page context, grid, orientation, header, footer, debugGrid |
| tag     | Tagged PDF: structure elements and artifacts |
| state   | Keep font and colour across a block |
| measure | How tall a block will be, before drawing it |
| layout  | Blocks one under another, with page breaks |
| text    | Unicode-safe text, line wrapping, sub/superscript, math symbols |
| math    | Inline math formula rendering (eqn-notation, Wiki-style) |
| table   | Tables: draw (recommended), simpleTable, render |
| drawing | Shapes, gradients, text transformations, roundedRect |
| unicode | Sanitization, emoji fallbacks, BOM removal |
| image   | Image embedding with automatic page breaks |
| units   | Unit conversion: mm/cm/inch <-> points |
| form    | Form layout: label+field, sections, order tables |
| core    | readFile, version, validate_pdf |
| tag     | Structure elements and artifacts, silent when tagging is off |

> **Note:** several modules are distributed as separate packages, each
> with its own reference page:
>
> | package | namespace | |
> |---|---|---|
> | `pdf4tcltable` | `tablelist` | [export a tablelist widget](pdf4tcltable.md) |
> | `pdf4tcltext` | `textwidget` | [export a Tk text widget](pdf4tcltext.md) |
> | `pdf4tclforms` | `forms` | [declarative fillable forms](pdf4tclforms.md) |
> | `pdf4tcllabels` | `labels` | [label sheets and roll labels](pdf4tcllabels.md) |
> | `pdf4tcltoc` | `toc` | [table of contents](pdf4tcltoc.md) |
> | `pdf4tclchart` | `chart` | [bar, line and pie charts](pdf4tclchart.md) |
> | `pdf4tclflow` | `flow` | [text through columns and pages](pdf4tclflow.md) |

> **Tagged PDF:** with `$pdf tagged 1` the building blocks mark up what they
> draw -- tables as `Table`/`TR`/`TH`/`TD`, form fields as `Form` with their
> label, running heads and page numbers as artifacts. Nothing changes
> without that one call. See [`accessibility.md`](accessibility.md) and
> [`../examples/basic/39_accessible.tcl`](../../../examples/basic/39_accessible.tcl).

---

## fonts

`fonts::init` searches automatically for DejaVuSansCondensed TTF fonts.
On success: TTF subset with 256+ Unicode characters.
Fallback: Helvetica (Type1, WinAnsi).

```tcl
# Init (once per process)
pdf4tcllib::fonts::init ?-fontdir /path/to/ttf?

# Accessor procs (always use these -- never hardcode font name strings)
pdf4tcllib::fonts::fontSans             ;# "Pdf4tclSans" or "Helvetica"
pdf4tcllib::fonts::fontSansBold         ;# "Pdf4tclSansBold" or "Helvetica-Bold"
pdf4tcllib::fonts::fontSansItalic       ;# "Pdf4tclSansItalic" or "Helvetica-Oblique"
pdf4tcllib::fonts::fontSansBoldItalic   ;# "Pdf4tclSansBoldItalic" or "Helvetica-BoldOblique"
pdf4tcllib::fonts::fontMono             ;# "Courier"
pdf4tcllib::fonts::hasTtf               ;# 1 if Regular/Bold TTF loaded
pdf4tcllib::fonts::hasTtfItalic         ;# 1 if Oblique TTF loaded

# Width factor (for text::width fallback)
pdf4tcllib::fonts::widthFactor $fontName
```

### fonts::setFont

Convenience wrapper around `$pdf setFont` with an optional style string:

```tcl
pdf4tcllib::fonts::setFont $pdf 12 Helvetica Bold
pdf4tcllib::fonts::setFont $pdf 11 Helvetica Italic
pdf4tcllib::fonts::setFont $pdf 10 Helvetica BoldItalic
pdf4tcllib::fonts::setFont $pdf 12 Helvetica {}     ;# normal weight

# When TTF is loaded: uses fontSansBold etc. automatically
pdf4tcllib::fonts::setFont $pdf 12 DejaVu Bold
# -> $pdf setFont 12 [pdf4tcllib::fonts::fontSansBold]
```

Style strings: `Bold`, `Italic`, `BoldItalic`, `Oblique`, `BoldOblique`.
Built-in mappings for Helvetica, Times-Roman and Courier.
Fallback: `family-style` (e.g. `Helvetica-Bold`).

Important: always obtain Italic/BoldItalic via `fontSansItalic` /
`fontSansBoldItalic` -- never hardcode `"Helvetica-Oblique"`. With TTF,
DejaVuSansCondensed-Oblique.ttf and -BoldOblique.ttf are loaded.
Consistent metrics prevent spacing errors in pdftotext round-trips.

### CID-Mode -- full Unicode coverage

By default, `fonts::init` uses `pdf4tcl::createFontSpecEnc` which limits
the embedded glyph set to **256 characters**: ASCII + Latin-1 Supplement
+ 32 selected extras (arrows, box drawing, le/ge, etc.). Sufficient
for typical Western text. Greek letters and most math symbols are
**outside this subset** and get replaced with `?` by
`unicode::sanitize`.

For full Unicode support pass `-cid 1`:

```tcl
pdf4tcllib::fonts::init -cid 1
```

This switches to `pdf4tcl::createFontSpecCID` (Identity-H encoding,
full TTF embedded). No 256-character limit -- any glyph the loaded
TTF contains can be rendered. Greek (α β γ), math symbols
(∞ ∑ ∫ √ ≤ ≥), arrows, set theory operators, even CJK if the TTF
covers them.

Trade-offs:

| | default (256-char) | `-cid 1` (CID) |
|---|---|---|
| Encoding | WinAnsi + 32 extras | Identity-H (Unicode) |
| Glyph coverage | ~250 | full TTF |
| PDF size (typical) | ~5-30 KB | ~150-700 KB |
| `unicode::sanitize` filter | active (Stage 2) | bypassed |
| Greek / math symbols | rendered as `?` | rendered correctly |

```tcl
# Query the mode after init
pdf4tcllib::fonts::isCidMode    ;# returns 1 or 0
```

When to use which:

- **Default mode**: smaller PDFs, plain Western text, programming docs
- **CID mode**: scientific documents, multilingual content, math
  formulae via `pdf4tcllib::math::renderFormula`

`isCidMode` is checked internally by `unicode::sanitize` to skip the
subset filter when CID is active.

---

## page

### The problem

Without pdf4tcllib, page size, margins and text area must be managed manually
in every coordinate calculation:

```tcl
# Without pdf4tcllib -- repeated everywhere:
set pageW  595.28              ;# A4
set margin [expr {20 * 2.835}]
set textW  [expr {$pageW - 2 * $margin}]
set startX $margin
set startY [expr {841.89 - $margin}]
```

### page::context

```tcl
# Keyword arguments:
set ctx [pdf4tcllib::page::context -paper a4 -margin 20 -landscape false]

# Positional (short form):
set ctx [pdf4tcllib::page::context a4 20 false]

# Access computed values:
dict get $ctx page_w    ;# 595.28  (page width in pt)
dict get $ctx page_h    ;# 841.89  (page height in pt)
dict get $ctx left      ;# 56.7    (left margin in pt)
dict get $ctx top       ;# 785.19  (top margin, measured from bottom)
dict get $ctx text_w    ;# 481.88  (printable width)
dict get $ctx text_h    ;# 728.49  (printable height)
dict get $ctx margin    ;# 56.7    (margin in pt)
```

### Context key aliases

Both conventions are valid and present in the same dict simultaneously:

| Long key | Short key | Meaning |
|---|---|---|
| page_w | PW | Page width |
| page_h | PH | Page height |
| left   | SX | Start X (left margin) |
| top    | SY | Start Y (top margin) |
| text_w | SW | Printable width |
| text_h | SH | Printable height |
| margin | margin_pt | Margin in points |

```tcl
# Both work:
set w [dict get $ctx page_w]
set w [dict get $ctx PW]
# ERROR: dict get $ctx pageW  (camelCase does not exist)
```

### Grid system

Divides the page into columns:

```tcl
# 3 columns, current column 0 (first)
lassign [pdf4tcllib::page::grid $pdf $ctx 3 0] gx gy gw gh
```

### Header and footer

Header (centered, with separator line) and footer (text left, page number right):

```tcl
pdf4tcllib::page::header $pdf $ctx "My Document"
pdf4tcllib::page::footer $pdf $ctx "Confidential" $pageNo
```

**The page label in the footer is German by default** -- `Seite 3`. It is
document content, not a message, and changing the default would silently
change the language of existing documents, so it stays. Two ways to set it:

```tcl
# once per application
set ::pdf4tcllib::page::pageLabelFormat "Page %s"

# or per call
pdf4tcllib::page::footer $pdf $ctx "Confidential" $pageNo 9 -pagelabel "Page %s"
```

`%s` is replaced by the page number. `page::number` next to it needs no
setting -- it writes the language-free `- 3 / 10 -`.

### Page number

```tcl
# Number only: "- 3 -"
pdf4tcllib::page::number $pdf $ctx 3

# With total: "- 3 / 10 -"
pdf4tcllib::page::number $pdf $ctx 3 10
```

### Which building blocks handle orient 0

`page::_advance`, `form::*` and `text::writeParagraph` work in both
directions. `table::draw` does **not**: since 0.6.3 it reads the
direction from the document, but it can only honour it for the page
break, so `-orient 0` is refused with an error rather than drawn
upside down -- see
[`table-draw.md`](table-draw.md#the-page-direction-063). Everything that
reads `page::context` assumes `top` and `bottom` measured from the top of
the page.

### _advance -- orient-aware y step (internal helper)

Moves `y` in the correct direction for the current orient mode.
Used internally by all `form::*` procs. Available for custom layout too.

```tcl
# orient true  (y grows down): y += step
# orient false (y grows up):   y -= step
pdf4tcllib::page::_advance $ctx y $step
```

Example:
```tcl
set ctx [pdf4tcllib::page::context a4 -orient true]
set y [dict get $ctx top]    ;# start at top margin

$pdf setFont 12 Helvetica
$pdf text "Line 1" -x $lx -y $y
pdf4tcllib::page::_advance $ctx y 16

$pdf text "Line 2" -x $lx -y $y
pdf4tcllib::page::_advance $ctx y 16
```

This works identically for both orient modes -- the caller never needs
to know which direction y travels.

### Debug grid (debugGrid)

Draws a coordinate grid -- only when `PDF4TCL_DEBUG=1` is set:

```tcl
pdf4tcllib::page::debugGrid $pdf $ctx        ;# 50pt grid
pdf4tcllib::page::debugGrid $pdf $ctx 25     ;# finer grid

# Enable:
set ::env(PDF4TCL_DEBUG) 1
```

### Orientation legend

Debug helper: draws page format, margins and text area:

```tcl
pdf4tcllib::page::orientationLegend $pdf $ctx
```

---

## text

### Unicode-safe text

Standard PDF fonts (Helvetica, Courier) cannot handle Unicode.
pdf4tcllib sanitizes automatically:

```tcl
set clean [pdf4tcllib::unicode::sanitize $text]
# Box-drawing:  | - -> + -> +
# Checkboxes:   [x]  [ ]
# Bullets:      *    ...
```

### Emoji fallbacks

Emojis are mapped to ASCII representations:

| Emoji | Fallback |
|---|---|
| Grinning Face | :-) |
| Party Popper | (!) |
| Thumbs Up | (+1) |
| Heart | <3 |
| Unknown | (U+FFFD) |

```tcl
# Integrated in readFile:
set text [pdf4tcllib::readFile "document.md"]
# Reads binary, removes BOM, replaces emoji
```

### text::writeParagraph -- automatic line wrapping

```tcl
set newY [pdf4tcllib::text::writeParagraph $pdf $x $y $width $text \
    -fontsize 11 -leading 14]
# Returns the Y position after the last line
```

Since pdf4tcllib 0.2 (pdf4tcl 0.9.4.23+): uses `drawTextBox -newyvar`
for exact Y position. Falls back to line-count estimation for older pdf4tcl.

### text::width -- measuring text width

```tcl
# Without pdf object: character-class estimation (fallback)
set w [pdf4tcllib::text::width $text $fontSize $fontName]

# With pdf object (pdf4tcl 0.9.4.23+): exact font metrics
set w [pdf4tcllib::text::width $text $fontSize $fontName $pdf]
```

The optional `$pdf` argument activates `getStringWidth -font -size` from
pdf4tcl 0.9.4.23, giving exact widths from TTF font tables.

`text::truncate` and `text::wrap` also accept the optional `$pdf` argument:

```tcl
set t     [pdf4tcllib::text::truncate $text $maxW $fontSize $fontName $pdf]
set lines [pdf4tcllib::text::wrap     $text $maxW $fontSize $fontName 0 $pdf]
```

`table::render` and `_calcColWidths` pass `$pdf` through automatically --
no manual call needed.

With a CID font, `$pdf` is **not optional**. Without it `width` estimates
from character classes, and the estimate does not know the font.
Measured with DejaVu Sans as a CID font, `w35 Mo 17.08.26 CC Sped1` at
size 8: 110.73 points exact against 89.44 estimated.

### text::wrap -- where a line may break

```tcl
set lines [pdf4tcllib::text::wrap $text $maxW $fontSize $fontName \
        $codeContinuation $pdf $hardBreak $separators]
```

Breaks at spaces, and inside a word at a hyphen or slash **between two
characters**. The separator stays at the end of the line, so
`Muster-Beispiel-Stadt` in a narrow column becomes `Muster-` /
`Beispiel-Stadt` rather than being cut character-wise in the middle of a
word.

A hyphen after anything but a letter or digit does not break, so
`-5 Euro` stays together -- the same rule pdf4tcl uses in `drawTextBox`
since 0.9.4.60. Before pdf4tcllib 0.6.3 the two disagreed, and the same
string came out differently depending on which of them drew it.

The separators are the last argument and default to `{- /}`; pass `{}`
for the pre-0.6.3 behaviour.

### text::fitSize and text::fits -- shrink rather than cut

```tcl
set size [pdf4tcllib::text::fitSize $text $maxW $wanted $fontName \
        -min 6 -pdf $pdf]
set ok   [pdf4tcllib::text::fits $text $maxW $size $fontName $pdf]
```

`truncate` cuts, and sometimes that is the wrong answer: `Sped1` and
`Sped2` differ in the last character, so a shortened delivery note sends
the driver on the other tour. The same for two customers of one family,
and for numbers with decimals -- 12.12 cut is 12.1, which also exists.

`fitSize` returns the largest size at which the text still fits, down to
`-min` (default 6). Below that it stops and returns `-min`; the caller
decides whether to let it overhang or cut after all. A `-min` above the
wanted size is clamped to the wanted size.

### Baseline positioning

Important: `$pdf text` positions at the **baseline**, not at the top of
the letters.

```
    Ascent       <- approx. 0.75 x fontSize above baseline
    ----------
    Hello World  <- Baseline (where pdf4tcl places the text)
    ----------
    Descent      <- approx. 0.25 x fontSize below baseline
```

For text inside boxes:

```tcl
# baseline = boxY + fontSize
# Ascenders reach ~0.75*fontSize upward
set baseline [expr {$boxY + $fontSize}]
$pdf text "Hello" -x $boxX -y $baseline
```

### text::expandTabs -- replace tabs with spaces

```tcl
set out [pdf4tcllib::text::expandTabs $line $tabWidth]
```

Replaces tab characters with the configured number of spaces (default 4).
Useful before passing code-like text to `text::wrap` because tabs render
unpredictably in PDF.

### text::detectFont -- heuristic font choice

```tcl
set fontName [pdf4tcllib::text::detectFont $line]
```

Returns `"Courier"` if `$line` looks like code (heavy use of `(){};:`
characters, leading whitespace, or all-monospace patterns), else the
default Sans font. Helper for auto-styling unstructured paragraphs.

### text::superscript / text::subscript -- inline math basics

```tcl
set width [pdf4tcllib::text::superscript $pdf $str $x $y $fontSize $fontName]
set width [pdf4tcllib::text::subscript   $pdf $str $x $y $fontSize $fontName]
```

Renders `$str` at reduced size (70% of `$fontSize`) with a baseline shift:
0.35x up for superscript, 0.20x down for subscript. Returns the rendered
text width so the caller can advance `$x` for the next segment.

The procs reset the font to `($fontSize, $fontName)` after rendering so
subsequent text resumes at the original size.

Typical use -- combine for `H_2O` or `E=mc^2`:

```tcl
set x 100; set y 100
$pdf setFont 14 Helvetica
$pdf text "H" -x $x -y $y
set x [expr {$x + [$pdf getStringWidth "H"]}]
set w [pdf4tcllib::text::subscript $pdf "2" $x $y 14 Helvetica]
set x [expr {$x + $w}]
$pdf text "O" -x $x -y $y
```

Full LaTeX (fractions, roots, integrals with limits) is **not** rendered
by these helpers -- they're intentionally a minimal subset. For full
math, render with KaTeX-CLI to SVG and embed via image.

### text::mathSymbol / text::mathSymbolNames -- LaTeX-name to Unicode

```tcl
set ch    [pdf4tcllib::text::mathSymbol alpha]   ;# returns "α"
set ch    [pdf4tcllib::text::mathSymbol cdot]    ;# returns "·"
set ch    [pdf4tcllib::text::mathSymbol unknown] ;# returns ""
set names [pdf4tcllib::text::mathSymbolNames]    ;# sorted list of all names
```

Lookup table for ~67 common LaTeX math symbol names mapped to their
Unicode equivalents. Categories:

| Category | Examples |
|----------|----------|
| Greek lower | `alpha`, `beta`, ..., `omega` |
| Greek upper | `Alpha`, `Beta`, ..., `Omega` |
| Operators | `cdot`, `times`, `div`, `pm`, `mp` |
| Comparison | `le`, `ge`, `ne`, `approx`, `equiv` |
| Big symbols | `sum`, `prod`, `int`, `partial`, `nabla`, `sqrt`, `infty` |
| Arrows | `to`, `gets`, `Rightarrow`, `Leftarrow` |
| Set theory | `in`, `notin`, `subset`, `supset`, `cup`, `cap`, `emptyset` |
| Logic | `forall`, `exists` |
| Misc | `deg`, `prime` |

Unknown names return `""` -- caller decides on fallback (e.g. render
the raw LaTeX-style string).

```

---

## unicode

Guards against pdf4tcl crashes on characters outside the active font and
normalizes input. Every drawing path in the library routes text through it.

```tcl
# Sanitize and draw (passes -x/-y/-align through to $pdf text)
pdf4tcllib::unicode::safeText $pdf "Total: 5 EUR" -x $x -y $y

# Sanitize a string without drawing
set clean [pdf4tcllib::unicode::sanitize $raw]

# Read a file, strip the BOM and apply emoji fallbacks
set text [pdf4tcllib::unicode::readFile report.md]
```

| Proc | Purpose |
|------|---------|
| `safeText pdf text ?-x -y -align …?` | Sanitize, then draw; forwards options to `$pdf text` |
| `sanitize text` | Return the cleaned string (box-drawing, symbols, `€` → replacements) |
| `readFile path` | Read a file, remove the BOM, apply emoji fallbacks |
| `preprocessBytes bytes` | Low-level byte preprocessing |

With TTF/CID fonts loaded (`fonts::init -cid 1`) most characters render
directly; without them `sanitize` maps them to ASCII/WinAnsi equivalents.
See the [text](#text) section for `safeText` usage in context.

---

### Which characters went missing (0.6.3)

```tcl
pdf4tcllib::unicode::resetSubst
pdf4tcllib::unicode::safeText $pdf $text -x 50 -y 100

set r [pdf4tcllib::unicode::substReport]
# -> count 3 chars {U+03B1 U+03B2 U+2211}
```

`sanitize` replaces a character the font does not have with `?`. Until
0.6.3 that happened silently: neither the return value nor a counter said
anything. Measured on `math::renderLatex`, `\alpha \sum` without
`fonts::init -cid 1` produced six question marks in the content stream,
and nothing pointed at it.

| Command | |
|---|---|
| `unicode::substCount` | how many characters were replaced |
| `unicode::substReport` | `count` and `chars` — up to twelve distinct code points |
| `unicode::resetSubst` | set both back |

The counter is cumulative, queryable and resettable, like `getSubstCount`
in pdf4tcl. A one-time warning goes to stderr as well, because a counter
only helps whoever asks it.

**Not counted** are substitutions that are intended and lose nothing: the
emoji transliteration (U+1F600 → `:-)`) and the box-drawing characters in
base mode. Counted is where a character disappears.

Latin-1 passes through, so German text does not raise a false alarm.


## math

Inline math formula rendering -- port of Arjen Markus' canvas-based
"MathFormula" from the Tcler's Wiki (2002-2007), adapted to PDF output.

Original: https://wiki.tcl-lang.org/page/Rendering+mathematical+formulae

### Notation

Whitespace-separated tokens, eqn/Wiki-style (not LaTeX):

| Token | Effect |
|-------|--------|
| `^` | Next token is superscript |
| `_` | Next token is subscript |
| `~` | Forced space |
| `` ` `` | Forced extra space (small kerning) |
| `alpha beta gamma ...` | Greek lowercase letters |
| `Alpha Beta Sigma ...` | Greek uppercase letters |
| `SUM INT PROD` | Big operators (∑ ∫ ∏) |
| `from VAL` | Lower limit (after SUM/INT/PROD) |
| `to VAL` | Upper limit |
| `infty sqrt cdot le ge ne approx ...` | Math symbols via `text::mathSymbol` |
| `rightarrow leftarrow Rightarrow Leftarrow` | Arrows |

Important: `from` and `to` are **always** treated as limit keywords
when they appear in a formula. For the right-arrow symbol use
`rightarrow` (resolves to `→`).

### math::renderFormula

```tcl
pdf4tcllib::math::renderFormula $pdf $x $y $formula ?-size N? ?-font NAME?
```

Renders `$formula` starting at (`$x`, `$y`) in `$pdf`. Returns the
end X-position (useful for chaining or measurement).

Options:

- `-size N` -- font size in points (default 12). Sub/superscripts
  automatically scale to 70%.
- `-font NAME` -- font name. Default: `pdf4tcllib::fonts::fontSans`
  if TTF loaded, else `Helvetica`.

### Requirements

For Greek letters and math symbols to render correctly, the fonts
module must run in **CID mode**:

```tcl
pdf4tcllib::fonts::init -cid 1
```

Without CID mode, Greek and most math symbols appear as `?` (see the
fonts section above).

### Examples

```tcl
package require pdf4tcl
package require pdf4tcllib

pdf4tcllib::fonts::init -cid 1

set pdf [pdf4tcl::new %AUTO% -paper a4]
$pdf startPage

# Einstein: E = mc²
pdf4tcllib::math::renderFormula $pdf 100 100 "E = mc ^ 2" -size 14

# H₂O
pdf4tcllib::math::renderFormula $pdf 100 130 "H _ 2 O" -size 14

# Quadratic formula
pdf4tcllib::math::renderFormula $pdf 100 160 \
    "x = ( -b pm sqrt ( b ^ 2 - 4ac ) ) / 2a" -size 14

# Sum with limits
pdf4tcllib::math::renderFormula $pdf 100 200 \
    "SUM from i=0 to infty ~ a _ i ~ x ^ i" -size 14

# Greek + partial derivative
pdf4tcllib::math::renderFormula $pdf 100 230 \
    "partial phi / partial t = D nabla ^ 2 phi" -size 14

$pdf write -file output.pdf
$pdf destroy
```

### The LaTeX subset -- math::renderLatex and math::measureLatex

Beside the eqn-style notation above there is a second, smaller entry
point that takes LaTeX-like input:

```tcl
lassign [pdf4tcllib::math::measureLatex $pdf {\frac{a}{b}} -size 12] \
        width above below
pdf4tcllib::math::renderLatex $pdf $x $y {E = mc^2} -size 12
```

`measureLatex` returns `{width heightAboveBaseline depthBelow}` so a
caller can centre a formula or check it fits before drawing;
`renderLatex` draws it with the baseline at `$y` and returns the x it
advanced to. `-font` defaults to the loaded TrueType when `fonts::init`
found one, otherwise to a built-in.

Measured on a document with DejaVu Sans at size 12:

| input | width, above, below |
|---|---|
| `x^2 + y^2 = z^2` | 50.95, 12.96, 2.40 |
| `\frac{a}{b}` | 9.83, 14.98, 11.38 |
| `\sqrt{x+1}` | 32.70, 10.64, 2.40 |
| `\sum_{i=1}^{n} i` | 16.20, 12.00, 12.60 |
| `\alpha \beta \gamma` | 20.40, 8.64, 2.40 |

So: superscripts and subscripts, fractions, roots, large operators with
limits, and the Greek letters. It is a subset, not LaTeX -- no
environments, no matrices, no `\left(...\right)` sizing.

**Greek and the operators need a font that has them.** Measured without
`fonts::init`: `\alpha \sum` produced six question marks in the content
stream, silently. Call `fonts::init -cid 1` first -- that is what
`68_math_formula.tcl` does, and why.

### On another backend: renderLatexOn and measureLatexOn

```tcl
set be [pdf4tcllib::math::pdfBackend $pdf]
pdf4tcllib::math::renderLatexOn $be $x $y {a^2 + b^2} -size 12 -font $font
```

The drawing goes through a backend object, so the same formula code can
write to a PDF or to a Tk canvas: `pdfBackend` and `canvasBackend` supply
one. `renderLatex` and `measureLatex` are the convenience forms that make
a PDF backend for you.

### math::analyseFormula

Exposed token parser -- useful for custom renderers or debugging:

```tcl
set tokens [pdf4tcllib::math::analyseFormula "E = mc ^ 2"]
# -> {E 0 0 1} {= 0 0 1} {mc 0 0 1} {2 0 -5 1}
#
# Format: {token x-offset y-offset advance}
#   advance=1 -> advance cursor by token width
#   advance=0 -> overlay (used internally for ^_ positioning)
```

### What is NOT supported

By design, since these require 2D layout that exceeds inline rendering:

- **Fractions** with horizontal bar (`\frac{a}{b}`) -- write `(a)/(b)`
  inline instead
- **Square roots with vinculum** -- write `sqrt(x+y)` with parens
- **Matrices** -- use `pdf4tcllib::table::draw` for 2D layouts
- **Multi-line equations** -- align manually with multiple
  `renderFormula` calls

For full LaTeX math with fractions, roots, integrals with limits etc.:
use an external rendering engine like KaTeX-CLI to produce SVG, then
embed via image module.

### Differences from Arjen's original Wiki version

| Wiki 2002 | Here |
|-----------|------|
| `Inf` for infinity | `infty` (LaTeX-style, matches `mathSymbol` table) |
| `PI`, `SIGMA` all-caps (with codepoint typos) | `Pi`, `Sigma` mixed-case, correct U+03Ax codepoints |
| `to` could mean both limit-keyword and `→` | `to` is always limit-keyword; use `rightarrow` for `→` |

---

## drawing

### drawing::roundedRect

Rectangle with rounded corners. Optionally as a clipping path.

```tcl
# Outline only
pdf4tcllib::drawing::roundedRect $pdf $x $y $w $h $r

# Filled
pdf4tcllib::drawing::roundedRect $pdf $x $y $w $h $r 1 1

# As clipping path (clip image to rounded rectangle)
$pdf gsave
pdf4tcllib::drawing::roundedRect $pdf $x $y $w $h 8 0 0 -clip 1
$pdf putImage $img $x $y -width $w -height $h
$pdf grestore
```

| Argument | Meaning |
|---|---|
| r | Corner radius in pt |
| stroke | 1 = draw outline (default: 1) |
| fill | 1 = fill area (default: 0) |
| -clip 1 | Use as clipping path (no drawing) |

### drawing::polygon, drawing::star

Regular polygons and stars:

```tcl
pdf4tcllib::drawing::polygon $pdf $cx $cy $radius $sides ?stroke? ?fill?
pdf4tcllib::drawing::star    $pdf $cx $cy $radius ?points? ?ratio? ?stroke? ?fill?
```

### drawing::gradient_v / gradient_h

Color gradient (vertical or horizontal):

```tcl
pdf4tcllib::drawing::gradient_v $pdf $x $y $w $h {1 0 0} {0 0 1} 40
pdf4tcllib::drawing::gradient_h $pdf $x $y $w $h {1 1 0} {0 1 0} 40
```

### drawing::textRotated / textScaled / textSkewed

Text transformations:

```tcl
# Rotated text (degrees counter-clockwise)
pdf4tcllib::drawing::textRotated $pdf "Hello" $x $y 45 12

# Scaled text
pdf4tcllib::drawing::textScaled  $pdf "Hello" $x $y 1.5 0.8 12

# Skewed text
pdf4tcllib::drawing::textSkewed  $pdf "Hello" $x $y 20 0 12
```

### drawing::watermark

A diagonal stamp across the page -- DRAFT, CONFIDENTIAL, a copy number.

```tcl
pdf4tcllib::drawing::watermark $pdf $ctx "DRAFT"
pdf4tcllib::drawing::watermark $pdf $ctx "COPY 3" -angle 30 -size 60 \
        -color {0.9 0.85 0.85}
```

Returns the font size used; with the default `-size 0` the text is fitted
to the page diagonal, which on A4 at 45 degrees gives about 163 pt for a
seven-letter word.

**Call it first on a page.** pdf4tcl has no alpha channel, so the stamp is
drawn in plain light grey and everything drawn afterwards sits on top of
it. The other way round it would hide the content.

It is marked as a Pagination artifact: it says something about the copy in
your hand, not about the text. See [`pdf4tclflow.md`](pdf4tclflow.md).

Since 0.6.3 the mark can go into an optional content layer instead of
onto the page:

```tcl
lassign [pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF" -layer 1] \
        size layer
# on the following pages, so they share one layer:
pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF" -layer $layer
```

A layer can be switched off in the reader, which is the point for a draft
mark: somebody who wants the text without it can have it. `-layer 1`
creates a layer named after the text and returns its id beside the size;
`-layer <id>` reuses one. Without the option the behaviour is unchanged.

The watermark stays a `Pagination` artifact in either case — a layer does
not make it content.

### drawing::arrow, drawing::arrowHead

```tcl
pdf4tcllib::drawing::arrow $pdf $x1 $y1 $x2 $y2 \
        -at end -length 8 -width 6 -filled 1

# a head alone, at the end of a path you drew yourself
pdf4tcllib::drawing::arrowHead $pdf $x $y $angleInRadians -length 8
```

A connection in a diagram is a line plus a triangle, and the triangle is
the work: it has to point along the line, and the line has to stop
**before** it -- otherwise it draws through the filled area and leaves a
seam down the middle. `-at` takes `end`, `start` or `both`.

The colour is whatever is set; the procedure does not change it. It draws
no curve -- for a bent connection draw the path yourself and put
`arrowHead` at its end.

Both are wrapped as artifacts: an arrow carries no text a reader could
announce. Without that every line and triangle counts as untagged, and a
diagram has as many holes in its structure tree as it has connections.

### drawing::callout

```tcl
set lines [pdf4tcllib::drawing::callout $pdf $x $y $w $h $targetX $targetY \
        $text -fill {0.95 0.95 0.8} -alt "note"]
```

A rounded box with a pointer at the side facing the target -- which side
follows from the geometry and is not an option.

| Option | Default | Meaning |
|---|---|---|
| `-radius` | 4 | corner radius |
| `-fill` | {} | `{r g b}`; {} = no fill |
| `-stroke` | 1 | outline |
| `-tail` | 12 | width of the pointer at the box |
| `-pad` | 5 | inner padding for the text |
| `-fontsize` | 9 | |
| `-font` | {} | otherwise `fonts::fontSans` |
| `-alt` | {} | makes the whole thing a `Figure` |

Text too tall for the box is set **smaller, not cut**: a speech bubble
usually holds one sentence, and half a sentence is none. The box and the
pointer are artifacts; the text inside is content and stays in the
structure tree.

### drawing::frame, drawing::separator

```tcl
# Simple border box
pdf4tcllib::drawing::frame     $pdf $x $y $w $h ?lineWidth?

# Horizontal separator line
pdf4tcllib::drawing::separator $pdf $x $y $w ?color? ?lineWidth?
```

---

## table

Three table APIs, from high-level to low-level:

| Proc | Use it for |
|------|-----------|
| **`table::draw`** | The recommended data-driven renderer: styling, zebra, per-cell/row colors and fonts, tree indent, footer, and automatic page breaks. Tk-free. |
| `table::simpleTable` | A quick table with fixed column widths in points. |
| `table::render` | Low-level engine (Markdown-style data, many positional args). `table::draw` wraps this. |

### table::draw (recommended)

```tcl
::pdf4tcllib::table::draw pdf x y cols data ?option value ...?
```

`cols` is a per-column option list, `data` is a list of rows of plain
cell strings. Styling is addressed by index (`-cellstyles`, `-rowstyles`),
so `data` stays free of markup.

```tcl
set cols {
    {-header "No."   -width 40   -align right}
    {-header "Item"  -width auto -align left}
    {-header "Price" -width 60   -align right}
}
set data {
    {1 "Laptop" "1,299.00"}
    {2 "Mouse"  "29.90"}
}

set y [pdf4tcllib::table::draw $pdf $x $y $cols $data \
    -ctx        $ctx \
    -zebra      1 \
    -cellstyles {0,2 {-fg {0.8 0 0} -font bold}} \
    -footer     {"" "Total" "1,328.90"} \
    -yvar       y]
```

With `-ctx` the table breaks across pages automatically and repeats the
header row on each page. Returns the next Y position.

Common options: `-ctx`, `-maxwidth`, `-header 0|1`, `-headerbg`, `-headerfg`,
`-zebra` / `-zebracolor`, `-fontsize`, `-pad`, `-border`, `-rowheight`,
`-cellstyles`, `-rowstyles`, `-rowindent`, `-footer` / `-footerbg` /
`-footerbold`, `-yvar`, `-pagevar`.

> Full reference: [`docs/en/reference/table-draw.md`](table-draw.md).

### simpleTable

Fixed column widths (points); the first row is the header:

```tcl
set colWidths {140 200 140}
set rows {
    {Name  Email               Role}
    {Alice alice@example.com   Admin}
    {Bob   bob@example.com     User}
}
pdf4tcllib::table::simpleTable $pdf $x $y $colWidths $rows \
    -zebra 1 -font_size 11
```

Signature: `simpleTable pdf x y col_widths rows ?-zebra 0|1 -pad N -header_bg {r g b} -row_height N -font_size N?`.
Returns the Y position below the table.

### table::render (low-level)

The underlying engine. `tableData` is `{header aligns row1 row2 ...}`
(a Markdown-style block); page breaks are driven by the caller-supplied
context values:

```tcl
proc render {pdf tableData x0 yVar maxW yTop yBot pageNoVar \
             pageW pageH margin fontSize lineH ?debug? ?pageBreakCmd?}
```

Prefer `table::draw`, which takes the same data more ergonomically
(`-ctx $ctx` replaces the seven positional layout arguments).

### table::breakPoints and table::fitRows -- where a table may be split (0.6.3)

```tcl
set n  [pdf4tcllib::table::fitRows $space $rows -groups $groups]
set bp [pdf4tcllib::table::breakPoints $rows -fontsize 9 -groups $groups]
```

`fitRows` answers how many rows go on a page of that height, stepping back
to the last allowed break. `breakPoints` returns `rowH`, `headerH`, the
cumulative `heights`, the number of `rows`, and `forbidden` -- the rows
**before which no break is allowed**.

Two things forbid one:

- **Inside a cell merged across rows.** It is not repeated on the
  following page, so a break would tear it apart. Measured: with a
  `rowspan 3` at the top, 60 points of space take no rows at all rather
  than two -- the whole block moves to the next page.
- **Directly after a group heading.** `table::group` returns those row
  numbers in `groups`; pass them in and they are honoured.

The row height in `table::draw` is uniform and its cells do not wrap, so
this is arithmetic rather than measurement. **It does not hold for
`table::render`**, which does wrap.

### table::widths -- the natural and the smallest width (0.6.3)

```tcl
set w [pdf4tcllib::table::widths $cols $rows -pdf $pdf]
dict get $w natural   ;# per column, nothing wraps
dict get $w min       ;# per column, the longest word still fits
```

Between the two a layout engine can distribute; below `min` something is
cut or breaks mid-word. `min` is the **longest word**, not the widest
character -- a word that does not fit is cut character-wise, and that is
not a lower bound but an emergency.

With a CID font `-pdf` is not optional; without it `text::width`
estimates from character classes.

### table::pivot -- a cross table (0.6.3)

```tcl
set p [pdf4tcllib::table::pivot $rows -row 0 -col 1 -value 2 \
        -agg sum -empty "" -rowlabel "Region"]

pdf4tcllib::table::draw $pdf $x $y $cols [dict get $p rows]
```

Rows of `{region quarter amount}` become a table with the regions as rows
and the quarters as columns. Returns a dict: `header`, `rows`, `cols`
(the column values, without the row label and the total column) and
`total` (the row number of the totals row, or -1).

| Option | Default | Meaning |
|---|---|---|
| `-row` / `-col` / `-value` | 0 / 1 / 2 | which column is which |
| `-agg` | sum | `sum`, `count`, `avg`, `min`, `max` |
| `-empty` | {} | what an empty cell says |
| `-total` | 1 | a totals column and a totals row |
| `-rowlabel` | {} | title of the first column |
| `-totallabel` | Gesamt | |
| `-colorder` | {} | column order; {} = sorted |

**The columns follow from the data.** A value that appears in no row does
not appear as a column; if you need all four quarters whether or not they
occur, pass `-colorder`.

**An empty cell is not a zero.** A cross table almost always has gaps,
and "nothing measured" is a different statement from "measured, zero".

A value that is not a number is skipped by `sum`, `avg`, `min` and `max`;
`count` counts it, because it counts rows rather than values.

### table::group -- subtotals per group (0.6.3)

```tcl
set g [pdf4tcllib::table::group $rows -by 0 -sum 2 -label "Summe %s"]

set styles {}
foreach r [dict get $g subtotals] { dict set styles $r {-font bold} }
pdf4tcllib::table::draw $pdf $x $y $cols [dict get $g rows] \
        -rowstyles $styles
```

Returns a dict: `rows` (with subtotals inserted), `subtotals`, `groups`
and `total` — the last three are row numbers, so the caller can style
them.

| Option | Default | Meaning |
|---|---|---|
| `-by` | 0 | column to group by |
| `-sum` | {} | columns to add up |
| `-label` | `Summe %s` | subtotal label; `%s` is the group value |
| `-total` | 1 | append a grand total |
| `-totallabel` | `Gesamt` | |
| `-header` | 0 | a heading row before each group |
| `-blank` | 0 | group value only in the first row of its group |
| `-strict` | 0 | raise on unsorted rows instead of warning |

**The rows have to be sorted by the group column.** They are not sorted
here — an order the caller chose deliberately is not the library's to
rearrange — but an unsorted list adds a warning to
`::pdf4tcl::warnings`, because otherwise a group falls into several
blocks and each gets its own subtotal.

A value that is not a number is skipped rather than counted as zero: an
empty field is not a zero.

The subtotal label is a merged cell spanning the columns before the first
summed one.

### Merged cells (0.6.3)

A cell may be a dict instead of a string:

```tcl
rows [list \
    [list [dict create text "Nord" rowspan 2] Q1 120] \
    [list Q2 90] \
    [list [dict create text "Summe" colspan 2] 210]]
```

Both `table::render` and `table::draw` understand them.

`colspan` adds up the widths of the covered columns; `rowspan` holds the
column in the following rows, and as in HTML the covered cells are simply
left out there — `Q2` above is the first entry of its row and belongs in
the *second* column.

The cell carries `/ColSpan` and `/RowSpan` (ISO 32000-1 table 349). That
is not decoration: clause 14.8.4.3.4 note 2 says the association between
a header and its data cells is determined heuristically and "may fail for
complex tables". A merged cell is exactly such a case, and without the
attribute a reader announces the wrong heading.

Recognised by a `text` key together with `colspan` or `rowspan`, so a
plain cell would have to read literally "text … colspan …" to be mistaken
for one. An unusable span — zero, negative, not a number — counts as one
rather than raising.

**Limitation:** a merged block that meets a page break is not repeated on
the next page. Nothing is lost and the tree stays complete, but the merge
is visually interrupted.

### When to use which

| Situation | API |
|---|---|
| Styling, colors, footer, tree, page breaks | **draw** |
| Fixed point widths, minimal setup | simpleTable |
| Embedding in an existing low-level layout loop | render |
| Tk `tablelist` widget → PDF | `pdf4tcltable` (separate package) |

---

## units

Convert between physical units and PDF points (1 pt = 1/72 inch).

```tcl
pdf4tcllib::units::mm   210   ;# 210 mm -> 595.28 pt  (A4 width)
pdf4tcllib::units::cm   2.5   ;# 2.5 cm -> 70.87 pt
pdf4tcllib::units::inch 1     ;# 1 inch -> 72.0 pt

pdf4tcllib::units::to_mm   595 ;# 595 pt -> 209.90 mm
pdf4tcllib::units::to_cm   72  ;# 72 pt  -> 2.54 cm
pdf4tcllib::units::to_inch 144 ;# 144 pt -> 2.0 inch
```

`mm` / `cm` / `inch` take a value and return points; `to_mm` / `to_cm` /
`to_inch` take points and return the value in that unit.

---

## image

Insert a Tk image into the PDF, proportionally scaled to a maximum width,
with automatic page breaks. Requires Tk (the image is a Tk photo/bitmap).

```tcl
set img [image create photo -file logo.png]

pdf4tcllib::image::insert $pdf $img \
    [dict get $ctx left] y \
    [dict get $ctx text_w] \
    [dict get $ctx top] [dict get $ctx bottom] pageNo \
    [dict get $ctx page_w] [dict get $ctx page_h] \
    [dict get $ctx margin] 10
```

- **insert** — centers the image across the full content width.
- **insertAt** — the same, but at an explicit X position (`xPos` instead of `x`).

Both scale the image proportionally to `maxW`, advance `yVar`, and start a new
page (updating `pageNoVar`) if the image would not fit.

```
image::insert   pdf tkImg x    yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize ?debug?
image::insertAt pdf tkImg xPos yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize ?debug?
```

### image::place -- fit a frame without distorting

```tcl
lassign [pdf4tcllib::image::place $pdf $id $x $y $w $h \
        -fit contain -anchor center -dpi 150 -alt "the plan"] bx by bw bh
```

`putImage` takes `-width` and `-height` and stretches the picture onto
them. Where the aspect ratio differs the picture is distorted, and
nothing says so.

| `-fit` | |
|---|---|
| `contain` | fits inside, margin stays free — nothing is lost |
| `cover` | fills the frame, overhang is cut — nothing stays empty |
| `stretch` | the old behaviour |

`-anchor` (`nw n ne w center e sw s se`) says where the picture sits
inside the frame with `contain`, and which part is dropped with `cover` —
a portrait with the head at the top wants `n`, a landscape usually
`center`.

Cutting is done with a clip path, so the picture is drawn at its computed
size and only the frame shows. What lies outside is still in the file;
crop beforehand if that matters.

`-dpi` warns below a threshold and switches off the core's own warning
for that call, because two messages about one picture are one too many.
`-alt` wraps the image in a `Figure`. Returns the area actually used —
smaller than the frame with `contain`, equal to it with `cover`.

### image::gallery -- a grid across pages

```tcl
set pages [pdf4tcllib::image::gallery $pdf $images $x $y $w $h \
        -cols 2 -rows 3 -gap 8 -caption unten -captionH 14]
```

Each entry is `{id "caption"}` or just `id`. Beyond the grid options it
takes `-fit`, `-anchor` and `-dpi` from `place`, plus `-fontsize`,
`-font` and `-pagecmd` (called before each new page, for a running head).

A caption is written **inside** the image's `Figure` as a `Caption`, so
the two belong together in the tree rather than standing next to each
other unconnected. A caption too wide for its cell is set smaller rather
than cut — see `text::fitSize`.

---
## form

The `form` namespace builds on top of `addForm` (pdf4tcl 0.9.4.1+) and
provides high-level procs for form-based PDFs: invoices, order forms,
customer data. Labels and fields are placed in a single call; `y` advances
automatically.

**Important:** `addForm` does not support CID fonts. The `form` namespace
uses Helvetica (standard fonts). Only WinAnsi characters are reliable in
form field text.

### Configuration

All sizes, colors and spacing values are configurable:

```tcl
# Show current config
pdf4tcllib::form::configure

# Set values
pdf4tcllib::form::configure \
    -fontSize 10 \
    -fieldH   18 \
    -labelW   100 \
    -fieldBg  {0.94 0.94 0.94}
```

| Option | Default | Meaning |
|---|---|---|
| fontFamily | Helvetica | Default font |
| fontFamilyBold | Helvetica-Bold | Bold font |
| fontSize | 9 | Field font size |
| fontSizeLabel | 9 | Label font size |
| fontSizeSection | 10 | Section header font size |
| fieldH | 16 | Field height in pt |
| fieldBg | {0.96 0.96 0.96} | Field background |
| fieldBorder | {0.70 0.70 0.70} | Field border |
| sectionBg | {0.88 0.88 0.88} | Section header background |
| labelColor | {0 0 0} | Label text color |
| lineColor | {0.70 0.70 0.70} | Separator line color |
| lineWidth | 0.5 | Line width |
| labelGap | 4 | Gap between label and field |
| rowGap | 6 | Gap between rows |
| sectionGap | 10 | Gap after section header |
| labelW | 90 | Default label width in pt |

### form::fieldHeight / form::rowHeight

Config accessors. `fieldHeight` returns the configured field height (`fieldH`);
`rowHeight` returns the full height of a form row (`fieldH + rowGap`). Useful to
compute layout / page-break space.

```tcl
set fh [pdf4tcllib::form::fieldHeight]
set rh [pdf4tcllib::form::rowHeight]
```

### form::section

Gray section header with title. Advances `y`.

```tcl
pdf4tcllib::form::section $pdf $ctx y "Customer Data"
```

### form::labelField

Label + form field in one call. Advances `y`.

```tcl
pdf4tcllib::form::labelField $pdf $ctx y "Name:"  text -id f_name
pdf4tcllib::form::labelField $pdf $ctx y "Email:" text -id f_email

# Custom widths:
pdf4tcllib::form::labelField $pdf $ctx y "Notes:" text \
    -id f_note -labelw 80 -fieldw 300 -fieldh 40 -multiline 1
```

All `addForm` options are passed through (`-id`, `-init`, `-options`,
`-readonly`, `-multiline`, `-required`, etc.).
Additional options: `-labelw`, `-fieldw`, `-fieldh`.

### form::row

Multiple label+field pairs side by side in one row.

```tcl
pdf4tcllib::form::row $pdf $ctx y {
    {label "ZIP:"  type text width  80 id f_zip}
    {label "City:" type text width 200 id f_city}
}
```

Each element is a dict with:

| Key | Required | Meaning |
|---|---|---|
| label | yes | Field label |
| type | yes | Field type (text checkbox combobox ...) |
| width | yes | Total width of label+field in pt |
| id | no | Field ID for addForm |
| init | no | Initial value |
| options | no | Options list (combobox/listbox) |
| labelw | no | Label width (default from config) |
| fieldh | no | Field height (default from config) |
| readonly | no | 1 = read-only |
| multiline | no | 1 = multiline text field |

### form::separator

Horizontal separator line. Advances `y`.

```tcl
pdf4tcllib::form::separator $pdf $ctx y
pdf4tcllib::form::separator $pdf $ctx y 8  ;# larger gap
```

### form::orderTable

Table with header row, zebra stripes and optional empty rows. Body cells are
static text by default, or fillable AcroForm fields with `-cellForm`.

```tcl
pdf4tcllib::form::orderTable $pdf $ctx y \
    {"Pos" "Item" "Qty" "Price"} \
    {30 200 50 80} \
    {} \
    -emptyRows 5

# Editable variant: every body cell becomes a text field (id = prefix_row_col)
pdf4tcllib::form::orderTable $pdf $ctx y \
    {"Pos" "Item" "Qty" "Price"} {30 200 50 80} {} \
    -emptyRows 5 -cellForm f_pos
```

| Argument | Meaning |
|---|---|
| headers | List of column headers |
| colWidths | List of column widths in pt |
| data | Data list (optional, empty for blank form) |
| -emptyRows N | Number of blank input rows (default: 0) |
| -rowh N | Row height (default: fieldH from config) |
| -headerBg {r g b} | Header background color |
| -cellForm idPrefix | Render body cells as fillable text fields (id = idPrefix_row_col); data rows are pre-filled. Without it: static text. |
| -cellOpts {col {opts} …} | Extra addForm options per column index (only with -cellForm), e.g. `{3 {-align right -format {number …}}}` |

### form::sumLine

Sum row at the end of an order table. The value is static text by default, or a
right-aligned calculated field with `-id`/`-calculate`/`-init`.

```tcl
# static value
pdf4tcllib::form::sumLine $pdf $ctx y {30 200 50 80} "Total:" "0.00 EUR"

# calculated: live sum over other fields (needs pdf4tcl 0.9.4.32+)
pdf4tcllib::form::sumLine $pdf $ctx y {30 200 50 80} "Total:" "" \
    -id f_total -calculate {sum {pos1 pos2 pos3}} -init "0"
```

| Argument | Meaning |
|---|---|
| colWidths | Column widths; label/value use the last two columns |
| label | Right-aligned bold label |
| value | Static text (used only without `-id`) |
| -id id | Render the value cell as a right-aligned form field |
| -calculate {op {fields}} | Live calculation via AFSimple_Calculate (op: sum/product/average/min/max); sets /CO + /NeedAppearances |
| -init value | Static pre-value shown in non-JS viewers |

### Complete example

```tcl
package require pdf4tcllib
pdf4tcllib::fonts::init

set pdf [pdf4tcl::new %AUTO% -paper a4]
set ctx [pdf4tcllib::page::context a4 -margin 20]
$pdf startPage
set y [dict get $ctx top]

pdf4tcllib::form::section    $pdf $ctx y "Customer"
pdf4tcllib::form::labelField $pdf $ctx y "Name:"  text -id f_name
pdf4tcllib::form::labelField $pdf $ctx y "Email:" text -id f_email
pdf4tcllib::form::row        $pdf $ctx y {
    {label "ZIP:"  type text width  80 id f_zip}
    {label "City:" type text width 200 id f_city}
}
pdf4tcllib::form::separator  $pdf $ctx y

pdf4tcllib::form::section    $pdf $ctx y "Order"
pdf4tcllib::form::orderTable $pdf $ctx y \
    {"Pos" "Item" "Qty" "Price"} {30 200 50 80} {} -emptyRows 5
pdf4tcllib::form::sumLine    $pdf $ctx y {30 200 50 80} "Total:" ""

$pdf endPage
$pdf write -file order.pdf
$pdf destroy
```

---

## tag

Tagged PDF: the structure tree. `$pdf tagged 1` turns it on in pdf4tcl;
these four wrap the calls so a building block does not have to care
whether tagging is on at all -- with it off they do nothing.

```tcl
pdf4tcllib::tag::begin $pdf P
pdf4tcllib::tag::begin $pdf Span
... draw ...
pdf4tcllib::tag::end $pdf
pdf4tcllib::tag::end $pdf
```

| Command | |
|---|---|
| `tag::begin $pdf <type> ?-option value ...?` | open an element; options are passed to `$pdf tagBegin` (`-alt`, `-scope`, `-colspan`, `-rowspan`, `-summary`) |
| `tag::end $pdf` | close it |
| `tag::artifact $pdf ?-type Layout\|Pagination\|Page?` | open an artifact -- decoration that carries no content |
| `tag::artifactEnd $pdf` | close it |
| `tag::isActive $pdf` | is tagging on for this document |
| `tag::depth $pdf` | how many elements are open right now |
| `tag::forget $pdf` | drop the bookkeeping for a destroyed document |

**Why `tag::depth` exists.** A building block that draws by itself has to
know whether it stands inside an open element or not, and it cannot ask
the document -- pdf4tcl keeps no such counter. Without it the block has
to choose between two wrongs: mark up unconditionally, and a `Span` ends
up nested inside a `P` that was opened by the caller; or never mark up,
and leave a hole in the tree. `safeText` had exactly that hole until
0.6.3: it marked up only sometimes, and the untagged operations were
invisible until `getUntaggedCount` was asked.

**What goes in an artifact.** Anything a reader should not announce
because it says nothing: zebra stripes, rules, the frame of a callout,
running heads, page numbers, a watermark. Everything that carries text a
reader would want gets an element instead.

The measure of whether a block got this right is `$pdf getUntaggedCount`:
it counts drawing operations that sit in neither. Zero is the goal, and
every module in this library is checked against it -- see
`tests/test_tagging.tcl`.

## state

Keeps the drawing state across a block. A building block leaves font and
colour as it last needed them, not as it found them: measured around
`table::draw`, 20 pt bold red went in and 9 pt regular black came out.

```tcl
pdf4tcllib::state::with $pdf {20 Helvetica-Bold} {1 0 0} {
    pdf4tcllib::table::draw $pdf ...
}

# or by hand
set z [pdf4tcllib::state::save $pdf 20 Helvetica-Bold {1 0 0}]
...
pdf4tcllib::state::restore $pdf $z
```

The values come from the caller because pdf4tcl has no getter for the
current font or colour -- `getFontMetric` exists, `getFont` does not.
What was not saved is not touched: a default would be a claim rather
than a restoration. `with` restores even when the block raises.

**Why not `gsave`/`grestore`.** The PDF pair `q`/`Q` does save the state,
and inside one page it is the right tool. But it applies per content
stream, and every page has its own: a `q` on page 1 with its `Q` on page
2 leaves two unbalanced streams -- and neither pdf4tcl nor qpdf says
anything, because each stream on its own stays readable. That happens
with every block that breaks pages by itself.

## measure

How tall will a block be, before it is drawn and before it is known which
page it goes on.

```tcl
set m [pdf4tcllib::measure::block mp {
    pdf4tcllib::table::draw $mp 0 0 $cols $rows -maxwidth 400 -ctx $ctx
} -paper a4]
dict get $m height    ;# how much height it needs
dict get $m pages     ;# how many pages it runs over
dict get $m value     ;# what the block returned
dict get $m overflow  ;# 1 if it ran past the sheet edge, 0 if not
dict get $m sheet     ;# the sheet height it was measured against

pdf4tcllib::measure::height mp $script ?-option ...?
pdf4tcllib::measure::fits $space mp $script ?-option ...?
```

The block is really drawn, into a throwaway document that is never
written, so the measurement is by construction the same thing that comes
out later. Fonts are shared across documents, so the throwaway one knows
the same CID fonts.

**The page count is a property of the call, not of the block.** Without
`-ctx`, `table::draw` does not break and draws past the page edge, and
the measurement says one page. Measure the way you will draw.

**`overflow` is what the page count cannot see.** The count rises only
when the block breaks pages *by itself*. A block that does not —
`text::writeParagraph`, for one — runs off the bottom instead, and
`pages` stays 1. Measured on a paragraph repeated thirty times on A4:
height 1207 against a sheet of 841.89, seventy-one lines of text, the
last one at y = -7.3, below the sheet. The measurement and the real run
agreed with each other, and both were wrong.

Neither checker catches that either: `geometry-check` does not look at
text, and `layout-check` reads through pdftotext, which drops what lies
beside the sheet — 359 of 360 words came back.

Since 0.6.4 `fits` reads `overflow` and answers no. Up to 0.6.3 it said
yes for a block that fitted on no page at all: the height was under the
space given, the page count was 1, and part of the text lay off the
sheet.

A block returning something other than a number gets an empty height
rather than an invented one.

## layout

```tcl
pdf4tcllib::layout::stack $pdf $x $y $w {
    {script {pdf4tcllib::text::writeParagraph $bpdf $intro $bx $by $bw}}
    {gap 12}
    {script {pdf4tcllib::table::draw $bpdf $bx $by $cols $rows
                    -maxwidth $bw} keep 1}
} -ctx $ctx -font {10 Helvetica}
```

Blocks one under another: the loop every report contains, written once.
Returns `y`, `pages` and `boxes` -- **one shape for all of them**,
`{x y w h}`, whether the block itself returns a y, an area or a line
count.

| Option | |
|---|---|
| `-ctx` | page context; without it nothing is broken |
| `-gap` | space between blocks |
| `-font {size name}` / `-fill {r g b}` | set before each block, restored after |
| `-pagecmd` | called after each page change |
| `-paper` | for the measuring |

`keep 1` measures the block first and starts a new page if it would not
fit whole. Without it nothing is measured and nothing is broken.

In each script `$bpdf`, `$bx`, `$by` and `$bw` are available. **`$bpdf`
rather than `$pdf`**: while measuring it is the throwaway document, and a
script naming `$pdf` would draw into the real one during the
measurement. The script runs in the caller's scope, so its own variables
are visible.

## Utility functions

### validate_pdf

Checks whether a file is a valid PDF:

```tcl
if {[pdf4tcllib::validate_pdf "output.pdf"]} {
    puts "PDF ok"
} else {
    puts "Invalid or not found"
}
```

### version

```tcl
puts [pdf4tcllib::version]
# -> 0.6.4   (the same number as [package provide pdf4tcllib])
```

### readFile

Binary read with automatic pre-processing:

```tcl
set text [pdf4tcllib::readFile "document.md"]
# 1. Read binary (no encoding issues)
# 2. Remove BOM
# 3. Replace emoji (preprocessBytes)
# 4. Unknown chars -> U+FFFD (sanitize)
```

---

## Interaction with other modules

```
pdf4tcl  (base)
  └── pdf4tcllib  (extensions)
        ├── mdpdf       (Markdown file -> PDF)
        └── mdhelp_pdf  (text widget -> PDF)
```

- **mdpdf** uses pdf4tcllib for Markdown-to-PDF conversion
- **mdhelp_pdf** uses pdf4tcllib for PDF export from the viewer
- Both use `page::context`, `text::writeParagraph`, `table::simpleTable`

---

## Common mistakes

### Text overflows cell border

```tcl
# WRONG -- baseline too high:
set textY [expr {$y0 + int(($cellH - $fontSize) / 2.0)}]

# RIGHT -- baseline low enough:
set textY [expr {$y0 + int(($cellH - $fontSize) / 0.45)}]
```

### Emoji in PDF

```tcl
# WRONG -- standard fonts cannot render emoji:
$pdf text "Hello :)" -x 50 -y 700

# RIGHT -- sanitize first:
set clean [pdf4tcllib::unicode::sanitize "Hello :)"]
$pdf text $clean -x 50 -y 700
```

### Dashes as text characters

```tcl
# WRONG -- width never matches exactly:
$pdf text [string repeat "-" 40] -x $x -y $y

# RIGHT -- real PDF line:
$pdf line $x $lineY [expr {$x + $width}] $lineY
```

### Wrong context key names

```tcl
# Both valid -- aliases in the same dict:
dict get $ctx page_w    ;# long form
dict get $ctx PW        ;# short form
# ERROR: dict get $ctx pageW  (camelCase does not exist)
```
