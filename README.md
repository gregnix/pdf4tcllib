# pdf4tcllib -- Extension library for pdf4tcl

pdf4tcllib fills the most common gaps in pdf4tcl:

- **TTF fonts** with automatic discovery (Linux, Windows, macOS)
- **Unicode safety** -- no more crashes on special characters
- **Text layout** -- line wrapping, width measurement, truncation
- **Tables** -- headers, zebra stripes, automatic page breaks, tagged for accessibility
- **Page management** -- PageContext, header, footer, page numbers
- **Drawing** -- gradients, polygons, stars, text rotation
- **Units** -- mm, cm, inches to points and back
- **Form layout** -- label+field, sections, order tables (`form` namespace)
- **Label sheets** -- Zweckform/Avery geometry, printer calibration, text fitting (`pdf4tcllabels`)
- **Table of contents** -- real page numbers and bookmarks, through a two-pass layout (`pdf4tcltoc`)
- **Charts** -- bar, line and pie from data, Tk-free, tagged as figures (`pdf4tclchart`)
- **Column flow** -- text through columns and pages, and a diagonal watermark (`pdf4tclflow`)


## Accessible documents (0.6.1)

Not only tables: with `$pdf tagged 1` every building block marks up what it
draws. Form fields sit in a `Form` element together with their label,
running heads and page numbers become Pagination artifacts, rules and
gradients Layout artifacts, a paragraph becomes a `P`.

pdf4tcl 0.9.4.43 counts what belongs to neither, so the result is checkable
rather than assumed:

```tcl
$pdf tagged 1
...
puts [$pdf getUntaggedCount]     ;# 0 is what PDF/UA asks for
```

A document built from header, paragraph, table, form section, field and page
number reports zero. Guide: [`docs/en/reference/accessibility.md`](docs/en/reference/accessibility.md),
runnable: [`examples/basic/39_accessible.tcl`](examples/basic/39_accessible.tcl).

## Accessible tables (0.6)

If the caller switches tagging on, `table::render` marks up what it draws:

```tcl
$pdf tagged 1 -lang de-DE
...
pdf4tcllib::table::render $pdf $data 0 y 500 20 750 pageNo 595 842 40 10 12
```

The result carries a proper structure -- `Table` / `TR` / `TH` with
`/Scope Column` / `TD` -- so a screen reader announces a table it can
navigate by row and column instead of a run of unrelated numbers. Grid lines,
background fills and zebra stripes become artifacts, since decoration
announced as content is worse than no tagging at all.

Both renderers do it: `table::render` and `table::draw`. Since
`pdf4tcltable` (tablelist export) delegates to `draw`, exporting a tablelist
widget produces an accessible table as well.

Nothing is switched on automatically. Without `$pdf tagged 1` every helper
does nothing and the output is byte for byte what it was before. Needs
pdf4tcl 0.9.4.36 or later for the tagging to take effect; older versions
simply keep working.

## Installation

Copy the modules you need into a directory on your `tcl::tm` path:

```tcl
tcl::tm::path add /path/to/lib
package require pdf4tcllib 0.6
```

`pdf4tcllib-0.6.1.tm` is one file and holds the core: fonts, unicode, text,
math, table, page, drawing, units, image, form, tag. The others are
separate packages, each usable on its own -- take only what you use.

| file | `package require` | |
|---|---|---|
| `lib/pdf4tcllib-0.6.1.tm` | `pdf4tcllib` | the core, needed by all of the below |
| `lib/pdf4tcltable-0.3.tm` | `pdf4tcltable` | export a Tk `tablelist` widget |
| `lib/pdf4tcltext-0.1.tm` | `pdf4tcltext` | export a Tk `text` widget |
| `lib/pdf4tclforms-0.2.tm` | `pdf4tclforms` | declarative AcroForm layouts |
| `lib/pdf4tcllabels-0.1.tm` | `pdf4tcllabels` | label sheets and roll labels |
| `lib/pdf4tcltoc-0.1.tm` | `pdf4tcltoc` | table of contents with real page numbers |
| `lib/pdf4tclchart-0.1.tm` | `pdf4tclchart` | bar, line and pie charts |
| `lib/pdf4tclflow-0.1.tm` | `pdf4tclflow` | text through columns and pages |

The only external dependency is pdf4tcl. `pdf4tcltable` and `pdf4tcltext`
additionally need Tk and the widget they export; nothing else needs Tk.

To bundle pdf4tcllib with another project, copy the modules you need
straight out of `lib/` -- the file name carries the version, which is
where Tcl reads it from. There is no second copy in this repository to
keep in step.

### Requirements

- **Tcl** 8.6 or later (works with 9.0)
- **pdf4tcl** 0.9.4.x or later -- required for TrueType font loading
  and Unicode CID support. Developed against the
  [gregnix fork](https://github.com/gregnix/pdf4tcl), which adds
  `createFontSpecCID`, Tagged PDF and `getUntaggedCount`; the upstream
  [pdf4tcl](https://sourceforge.net/projects/pdf4tcl/) works too, with
  the limits noted below.
- **TclOO** (bundled with Tcl 8.6+)

Older pdf4tcl versions without `loadBaseTrueTypeFont` / `createFontSpecCID`
will work but lose Unicode-TTF support -- only the built-in PDF Standard
fonts (Helvetica, Courier) remain usable.


## Quick start

```tcl
package require pdf4tcllib 0.6

# Initialize fonts (searches for TTF automatically)
pdf4tcllib::fonts::init

# Create page context
set ctx [pdf4tcllib::page::context a4 -margin 25]

# Create PDF
package require pdf4tcl
set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

# Set font and write text
$pdf setFont 14 [pdf4tcllib::fonts::fontSansBold]
pdf4tcllib::unicode::safeText $pdf "Hello World" -x 50 -y 50

# Text with automatic line wrapping
set newY [pdf4tcllib::text::writeParagraph $pdf 50 700 480 $longText \
    -fontsize 11 -leading 14]

# Table (data-driven; add -ctx for automatic page breaks)
set cols {{-header Name} {-header Age -align right} {-header City}}
set y [pdf4tcllib::table::draw $pdf [dict get $ctx left] $y $cols $rows \
    -ctx $ctx -zebra 1 -yvar y]

# Footer
pdf4tcllib::page::footer $pdf $ctx "My Document" 1

$pdf endPage
$pdf write -file output.pdf
$pdf destroy
```


## Coordinate system

pdf4tcllib uses **orient true** by default: origin at top-left, y grows downward
(same as Tk canvas and HTML). Always pass `-orient true` when creating the PDF object:

```tcl
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
set ctx [pdf4tcllib::page::context a4 -margin 25]   ;# default: orient true

set y [dict get $ctx top]     ;# start near top of page (small y value)
$pdf text "Line 1" -x $lx -y $y
set y [expr {$y + 16}]        ;# next line: y grows downward
```

All `form::*`, `table::render` and `image::insert` procs are orient-aware.
Use `page::_advance $ctx y $step` for layout code that works in both modes.


## Modules

### fonts -- Font management

```tcl
pdf4tcllib::fonts::init ?-fontdir /path? ?-family DejaVuSansCondensed? ?-cid 0/1?

pdf4tcllib::fonts::hasTtf              ;# -> 1/0
pdf4tcllib::fonts::isCidMode           ;# -> 1/0 (full Unicode if 1)
pdf4tcllib::fonts::fontSans            ;# -> "Pdf4tclSans" or "Helvetica"
pdf4tcllib::fonts::fontSansBold        ;# -> "Pdf4tclSansBold" or "Helvetica-Bold"
pdf4tcllib::fonts::fontSansItalic      ;# -> "Pdf4tclSansItalic" or "Helvetica-Oblique"
pdf4tcllib::fonts::fontSansBoldItalic  ;# -> "Pdf4tclSansBoldItalic" or "Helvetica-BoldOblique"
pdf4tcllib::fonts::fontMono            ;# -> "Courier"
pdf4tcllib::fonts::widthFactor $f      ;# -> 0.58

# Convenience wrapper around $pdf setFont with style strings
pdf4tcllib::fonts::setFont $pdf 12 Helvetica Bold
pdf4tcllib::fonts::setFont $pdf 11 Helvetica Italic
pdf4tcllib::fonts::setFont $pdf 10 Helvetica BoldItalic
```

**CID-mode** (`-cid 1`) embeds the complete TTF rather than a 256-char
subset. Required for Greek letters, math symbols, CJK and anything
outside Latin-1. PDFs become larger (~150 KB vs ~5 KB), but
`unicode::sanitize` no longer replaces these glyphs with `?`.

### unicode -- Crash protection

```tcl
set clean [pdf4tcllib::unicode::sanitize $text ?-mono 0?]
pdf4tcllib::unicode::safeText $pdf $text ?-mono 0? ?-x 50? ?-y 100?
```

Box-drawing characters, checkboxes and bullets are mapped to ASCII equivalents.
Emoji are replaced with readable fallbacks (`:-)`, `(+1)`, `<3`, ...).

### text -- Text layout

```tcl
# Line wrapping (returns new Y position)
set newY [pdf4tcllib::text::writeParagraph $pdf $x $y $width $text \
    -fontsize 11 -leading 14]

# Width measurement -- exact metrics with pdf4tcl 0.9.4.23+
set w [pdf4tcllib::text::width $text $fontSize $fontName]
set w [pdf4tcllib::text::width $text $fontSize $fontName $pdf]

# Truncate and wrap
set cut   [pdf4tcllib::text::truncate $text $maxW $fontSize $fontName ?$pdf?]
set lines [pdf4tcllib::text::wrap     $text $maxW $fontSize $fontName 0 ?$pdf?]

# Inline math helpers (sub/superscript + LaTeX-name lookup)
set w [pdf4tcllib::text::superscript $pdf "2" $x $y 14 $fontName]
set w [pdf4tcllib::text::subscript   $pdf "2" $x $y 14 $fontName]
set ch [pdf4tcllib::text::mathSymbol alpha]    ;# returns "α"
```

### math -- Inline math formulae (eqn/Wiki notation)

Port of Arjen Markus' MathFormula (Tcler's Wiki 2002-2007), adapted to
PDF. Requires CID-mode fonts for Greek + math symbols.

```tcl
# Init fonts with CID-mode for full Unicode
pdf4tcllib::fonts::init -cid 1

# Render formulae using whitespace-separated tokens
pdf4tcllib::math::renderFormula $pdf 100 100 "E = mc ^ 2"
pdf4tcllib::math::renderFormula $pdf 100 130 "H _ 2 O"
pdf4tcllib::math::renderFormula $pdf 100 160 \
    "SUM from i=0 to infty ~ a _ i ~ x ^ i"
pdf4tcllib::math::renderFormula $pdf 100 190 \
    "partial phi / partial t = D nabla ^ 2 phi"
```

Notation: `^` (superscript), `_` (subscript), `~` (forced space),
Greek names (`alpha beta`), big operators (`SUM INT PROD` with
`from`/`to` limits), math symbols (`infty sqrt cdot le ge ...`),
arrows (`rightarrow leftarrow`).

Not supported (use external KaTeX-CLI for these): fractions with
horizontal bar, square roots with vinculum, matrices, multi-line
equations. See `docs/en/reference/API.md#math` for the complete reference.

### table -- Tables

```tcl
# Recommended: data-driven, styling, footer, automatic page breaks
set cols {
    {-header "No."   -width 40   -align right}
    {-header "Item"  -width auto -align left}
    {-header "Price" -width 60   -align right}
}
set data {{1 "Laptop" "1,299.00"} {2 "Mouse" "29.90"}}
set y [pdf4tcllib::table::draw $pdf $x $y $cols $data \
    -ctx $ctx -zebra 1 -footer {"" "Total" "1,328.90"} -yvar y]

# Simple: fixed column widths in points (first row is the header)
pdf4tcllib::table::simpleTable $pdf $x $y {140 200 140} $rows -zebra 1
```

Full reference: `docs/en/reference/table-draw.md`. For a Tk `tablelist` widget use the
`pdf4tcltable` package (`docs/en/reference/pdf4tcltable.md`).

### page -- Page context

```tcl
set ctx [pdf4tcllib::page::context a4 ?-margin 25? ?-landscape 0?]
dict get $ctx text_w   ;# printable width in pt
dict get $ctx top      ;# top margin Y (measured from bottom)
dict get $ctx left     ;# left margin X

pdf4tcllib::page::header $pdf $ctx "Title"
pdf4tcllib::page::footer $pdf $ctx "Confidential" $pageNo
pdf4tcllib::page::number $pdf $ctx 3 10    ;# "- 3 / 10 -"

# Column grid
lassign [pdf4tcllib::page::grid $pdf $ctx 3 0] gx gy gw gh

# Debug coordinate grid (only active when PDF4TCL_DEBUG=1)
pdf4tcllib::page::debugGrid $pdf $ctx ?step?
```

### drawing -- Drawing functions

```tcl
# Gradients
pdf4tcllib::drawing::gradient_v $pdf $x $y $w $h {r g b} {r g b} ?steps?
pdf4tcllib::drawing::gradient_h $pdf $x $y $w $h {r g b} {r g b} ?steps?

# Shapes
pdf4tcllib::drawing::polygon     $pdf $cx $cy $radius $sides ?stroke? ?fill?
pdf4tcllib::drawing::star        $pdf $cx $cy $radius ?points? ?ratio? ?stroke? ?fill?
pdf4tcllib::drawing::roundedRect $pdf $x $y $w $h $r ?stroke? ?fill? ?-clip 1?
pdf4tcllib::drawing::frame       $pdf $x $y $w $h ?lineWidth?
pdf4tcllib::drawing::separator   $pdf $x $y $w ?color? ?lineWidth?

# Text transformations
pdf4tcllib::drawing::textRotated $pdf $text $x $y $angle $size ?font?
pdf4tcllib::drawing::textScaled  $pdf $text $x $y $sx $sy $size ?font?
pdf4tcllib::drawing::textSkewed  $pdf $text $x $y $skewX $skewY $size ?font?
```

### units -- Unit conversion

```tcl
pdf4tcllib::units::mm 25        ;# -> 70.87 pt
pdf4tcllib::units::cm 2.5       ;# -> 70.87 pt
pdf4tcllib::units::inch 1       ;# -> 72.0 pt
pdf4tcllib::units::to_mm 72     ;# -> 25.4 mm
pdf4tcllib::units::to_cm 72     ;# -> 2.54 cm
```

### image -- Images (requires Tk)

```tcl
pdf4tcllib::image::insert   $pdf $tkImg $x yVar $maxW ...
pdf4tcllib::image::insertAt $pdf $tkImg $xPos yVar $maxW ...
```

### form -- Form layout

High-level layout on top of `addForm` (pdf4tcl 0.9.4.1+). Labels and fields
are placed in a single call; `y` advances automatically.

```tcl
pdf4tcllib::form::section    $pdf $ctx y "Customer"
pdf4tcllib::form::labelField $pdf $ctx y "Name:"  text -id f_name
pdf4tcllib::form::labelField $pdf $ctx y "Email:" text -id f_email
pdf4tcllib::form::row        $pdf $ctx y {
    {label "ZIP:"  type text width  80 id f_zip}
    {label "City:" type text width 200 id f_city}
}
pdf4tcllib::form::separator  $pdf $ctx y
pdf4tcllib::form::orderTable $pdf $ctx y \
    {"Pos" "Item" "Qty" "Price"} {30 200 50 80} {} -emptyRows 5
# add -cellForm f_pos to make every table cell a fillable field
pdf4tcllib::form::sumLine    $pdf $ctx y {30 200 50 80} "Total:" ""
```

Note: `addForm` does not support CID fonts. The `form` namespace uses
Helvetica; only WinAnsi characters are reliable in form fields.

### pdf4tclforms -- fillable PDF forms (optional module)

```tcl
package require pdf4tclforms 0.2

set ctx [pdf4tcllib::page::context a4 -margin 25]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set y [dict get $ctx top]

# Built-in templates: callnote | inventory | checklist | order
# Or pass your own dict spec (see examples/advanced/61_pdf4tclforms_schema.tcl)
pdf4tclforms::renderSchema $pdf $ctx [pdf4tclforms::template callnote] -yvar y

$pdf endPage
$pdf write -file anrufernotiz.pdf
$pdf destroy
```

See `examples/advanced/60_pdf4tclforms_demo.tcl` (four sample PDFs: callnote, inventory, checklist, order)
and `examples/advanced/61_pdf4tclforms_schema.tcl` (custom schema without template).
Custom schemas: Wartungsprotokoll (61), Fehlermeldung (62).
Order form with a live subtotal, VAT and total: `examples/advanced/63_pdf4tclforms_bestellung.tcl`.
Full API reference: `docs/en/reference/pdf4tclforms.md`.

## pdf4tcllabels -- label sheets

Sheets of adhesive labels. The module owns the geometry, the caller writes
once what goes on a label.

```tcl
package require pdf4tcllabels

set sheets [::pdf4tcllib::labels::render $pdf 3474 $addresses {x y w h rec} {
    $pdf setFont 10 [::pdf4tcllib::fonts::fontSans]
    $pdf text [dict get $rec name] -x [expr {$x + 8}] -y [expr {$y + 20}]
} -start 2]
```

Formats 3427 (A6), 3474, 3475, 3483, Avery 4737, plus `define` for your
own. `calibration` writes a test sheet for the printer offset -- one to two
millimetres is the rule, not the exception, and `-offsetx`/`-offsety`
settle it permanently. `fitSize`, `wrap` and `ellipsize` fit text into the
box; with tagging on, every label is one structure element.

Full reference: `docs/en/reference/pdf4tcllabels.md`. Howtos:
`docs/en/howtos/howto-label-sheets.md`,
`docs/en/howtos/howto-shipping-labels.md`.

## pdf4tcltoc -- table of contents

A contents page with page numbers that are actually right, plus a bookmark
per heading. The catch is inherent: the page number of a heading is known
only after layout, and the contents itself shifts them. So the document is
laid out twice -- once into a throwaway document to learn the numbers, once
for real.

```tcl
package require pdf4tcltoc

set result [::pdf4tcllib::toc::document $pdf a4 {
    $pdf startPage
    set y [dict get $ctx top]
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Introduction"
    ...
    $pdf endPage
} -title "Contents"]
```

The content script therefore runs **twice** and must not have side effects.
With tagging on, the contents is a `TOC` element, each line a `TOCI`, and
the dot leaders are artifacts.

Full reference: `docs/en/reference/pdf4tcltoc.md`. Example:
`examples/basic/40_toc.tcl`.

## pdf4tclchart -- charts

Bar, line and pie, data-driven and Tk-free -- no canvas, no image.

```tcl
package require pdf4tclchart

set y [::pdf4tcllib::chart::bar $pdf $x $y $w 190 \
    {Jan 120 Feb 145 Mar 98 Apr 160} -title "Revenue" -values 1]
set y [::pdf4tcllib::chart::pie $pdf $x $y $w 200 \
    {North 35 South 25 East 20 West 20} -legend 1]
```

Every command takes a box and returns the y below the chart, so charts
stack like paragraphs. The scale is rounded to something a reader can
divide -- 137 becomes 150. The palette has six colours with distinct
lightness, so the chart survives being printed in grey. With tagging on,
a chart is one `Figure` element with an alternate text and everything
inside it is an artifact.

Full reference: `docs/en/reference/pdf4tclchart.md`. Example:
`examples/basic/41_charts.tcl`.

## pdf4tclflow -- columns, and a watermark

Text that fills column one, continues in column two and carries on at the
top of the next page.

```tcl
package require pdf4tclflow

set result [::pdf4tcllib::flow::columns $pdf $ctx $body -columns 2 -newpage {
    $pdf endPage
    $pdf startPage
    ::pdf4tcllib::drawing::watermark $pdf $ctx "DRAFT"
    ::pdf4tcllib::page::header $pdf $ctx "Chapter 1"
}]
```

The page break is a script the caller supplies -- only the caller knows
what a new page needs. Without it the flow stops at the last column and
returns what is left in `rest` rather than dropping it.

`drawing::watermark` draws a diagonal stamp, fitted to the page and marked
as a Pagination artifact. Call it **first** on a page: there is no
transparency in pdf4tcl, so it has to go underneath.

Note, measured: more columns do **not** save pages -- narrow columns break
more often. Columns are for readability, not density.

Full reference: `docs/en/reference/pdf4tclflow.md`. Example:
`examples/basic/42_columns.tcl`.


## Examples

```
examples/
  basic/     01-38   Individual features (fonts, text, drawing, tables, ...)
  advanced/  36-49   Complex applications (batch, forms, annotations, ...)
             d01-d08 Integration demos (multiple modules working together)
```

```bash
# Single script:
tclsh examples/basic/01_simple_page.tcl
tclsh examples/advanced/d06_invoice.tcl

# By group:
tclsh examples/basic/run_basic.tcl
tclsh examples/advanced/run_advanced.tcl

# Everything at once:
tclsh examples/run_all.tcl

# Options:
tclsh examples/run_all.tcl -novalidate   # skip PDF validator
tclsh examples/run_all.tcl -nodemos      # skip d01-d08
tclsh examples/run_all.tcl -nobasic      # advanced only
tclsh examples/run_all.tcl -noadvanced   # basic only
```


## Requirements

- pdf4tcl 0.9.4.23+ (recommended; 0.9.4.11+ minimum for basic use)
- Tcl 8.6+ (required)
- Tk (only for `pdf4tcllib::image`)
- DejaVu fonts (optional; falls back to Helvetica/Type1)


## Origin

Extracted and generalized from:

- mdhelp_pdf (TTF fonts, Unicode, tables)
- pdf4tcl_helpers (PageContext, drawing functions, text rotation)

All functions are designed for reuse in any pdf4tcl-based project.

## Running the tests

```bash
make test                 # 348 tests in 16 files
tclsh tests/run_all.tcl   # the same, directly
```

The GUI tests need Tk and a display; without one they are counted as
skipped, not as passes. On a headless machine:

```bash
Xvfb :99 -screen 0 1280x1024x24 & export DISPLAY=:99
```

The examples write PDFs and check them with `qpdf`, `pdfinfo` and
`pdffonts` where those are installed:

```bash
tclsh examples/run_all.tcl          # 41 basic, 36 advanced
tclsh docs/en/run-all-examples.tcl  # every howto and tutorial
```

Every script under `docs/en/` runs and reports how much of its own content
it left outside the structure tree. Zero is the point of the exercise.

## Contributing

Two habits this library is built on, and pull requests are held to them:

**Measure, do not assert.** A claim in a comment, a README or a test needs
to have been run. Several of the bugs found here were in code that looked
right and in tests that were green for the wrong reason.

**Every change gets a test, and every test gets a counter-test.** Switch
the change off and check that the test goes red. A test that passes without
the fix measures nothing -- that has happened here often enough to make it
a rule.

## License

BSD 2-Clause License. See [LICENSE](LICENSE) for details.

Copyright (c) 2026 Gregor (gregnix).

Copyright (c) 2026 Gregor (gregnix)
