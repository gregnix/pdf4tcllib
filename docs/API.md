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
| fonts   | Font management: TTF search, fallback, accessor procs, setFont |
| page    | Page context, grid, orientation, header, footer, debugGrid |
| text    | Unicode-safe text, line wrapping |
| table   | Tables (simpleTable + render) |
| drawing | Shapes, gradients, text transformations, roundedRect |
| unicode | Sanitization, emoji fallbacks, BOM removal |
| image   | Image embedding with automatic page breaks |
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

### simpleTable (high-level)

One call, automatic column widths:

```tcl
set headers {Name Age City}
set rows {
    {Alice 30 Berlin}
    {Bob   25 Hamburg}
    {Carol 35 Munich}
}
pdf4tcllib::table::simpleTable $pdf $ctx $headers $rows
```

Features: automatic equal column widths, gray header background,
zebra stripes, border lines.

### table::render (low-level)

Full control over column widths, alignment and colors:

```tcl
set cols {
    {width 40  align left   header "No."}
    {width 120 align left   header "Item"}
    {width 60  align right  header "Price"}
}
set data {
    {1 "Laptop" "1,299.00"}
    {2 "Mouse"  "29.90"}
}
pdf4tcllib::table::render $pdf $x $y $cols $data
```

### When to use which API

| Situation | API |
|---|---|
| Quick data table | simpleTable |
| Custom column widths | render |
| Per-column alignment | render |
| Order form, invoice | render |
| Debug output, overview | simpleTable |

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

Table with header row, zebra stripes and optional empty rows.

```tcl
pdf4tcllib::form::orderTable $pdf $ctx y \
    {"Pos" "Item" "Qty" "Price"} \
    {30 200 50 80} \
    {} \
    -emptyRows 5
```

| Argument | Meaning |
|---|---|
| headers | List of column headers |
| colWidths | List of column widths in pt |
| data | Data list (optional, empty for blank form) |
| -emptyRows N | Number of blank input rows (default: 0) |
| -rowh N | Row height (default: fieldH from config) |
| -headerBg {r g b} | Header background color |

### form::sumLine

Sum row at the end of an order table.

```tcl
pdf4tcllib::form::sumLine $pdf $ctx y {30 200 50 80} "Total:" "0.00 EUR"
```

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
