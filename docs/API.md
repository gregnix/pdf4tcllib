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
package require pdf4tcllib 0.2

# Or in vendors/tm/ (mdstack, mdhelp4)
tcl::tm::path add vendors/tm
package require pdf4tcllib 0.2
```

Dependency: pdf4tcl (in `vendors/pkg/` or system-wide).

## Module overview

| Namespace | Purpose |
|---|---|
| fonts   | Font management: TTF search, fallback, accessor procs, setFont, CID-mode |
| page    | Page context, grid, orientation, header, footer, debugGrid |
| text    | Unicode-safe text, line wrapping, sub/superscript, math symbols |
| math    | Inline math formula rendering (eqn-notation, Wiki-style) |
| table   | Tables: draw (recommended), simpleTable, render |
| drawing | Shapes, gradients, text transformations, roundedRect |
| unicode | Sanitization, emoji fallbacks, BOM removal |
| image   | Image embedding with automatic page breaks |
| units   | Unit conversion: mm/cm/inch <-> points |
| form    | Form layout: label+field, sections, order tables |
| core    | readFile, version, validate_pdf |

> **Note:** `tablelist` and `textwidget` modules are distributed as
> separate packages (`pdf4tcltable`, `pdf4tcltext`) since version 0.2.

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

### Page number

```tcl
# Number only: "- 3 -"
pdf4tcllib::page::number $pdf $ctx 3

# With total: "- 3 / 10 -"
pdf4tcllib::page::number $pdf $ctx 3 10
```

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
package require pdf4tcllib 0.2

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

> Full reference: [`docs/table-draw.md`](table-draw.md).

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
package require pdf4tcllib 0.2
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
# -> 0.2
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
