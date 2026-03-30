# pdf4tcllib -- Extension library for pdf4tcl

pdf4tcllib fills the most common gaps in pdf4tcl:

- **TTF fonts** with automatic discovery (Linux, Windows, macOS)
- **Unicode safety** -- no more crashes on special characters
- **Text layout** -- line wrapping, width measurement, truncation
- **Tables** -- headers, zebra stripes, automatic page breaks
- **Page management** -- PageContext, header, footer, page numbers
- **Drawing** -- gradients, polygons, stars, text rotation
- **Units** -- mm, cm, inches to points and back
- **Form layout** -- label+field, sections, order tables (`form` namespace)


## Status

> **Educational material.**
> This library and its examples are designed for learning and training purposes --
> exploring pdf4tcl features, understanding PDF generation patterns, and
> experimenting with Tcl/Tk. Feedback and contributions are welcome.


## Installation

Single file -- no subdirectory needed:

```
myproject/
  tm/
    pdf4tcllib-0.1.1.tm   (single file, all 9 modules)
```

```tcl
tcl::tm::path add /path/to/tm
package require pdf4tcllib 0.1.1
```

All modules (fonts, unicode, text, table, page, drawing, units, image, form)
are contained in one file. The only external dependency is pdf4tcl.


## Quick start

```tcl
package require pdf4tcllib 0.1.1

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

# Table
pdf4tcllib::table::simpleTable $pdf $ctx {Name Age City} $rows

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
pdf4tcllib::fonts::init ?-fontdir /path? ?-family DejaVuSansCondensed?

pdf4tcllib::fonts::hasTtf              ;# -> 1/0
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
```

### table -- Tables

```tcl
# High-level: automatic column widths, zebra stripes, header row
pdf4tcllib::table::simpleTable $pdf $ctx $headers $rows

# Low-level: full control over widths, alignment, colors
set cols {
    {width 40  align left   header "No."}
    {width 120 align left   header "Item"}
    {width 60  align right  header "Price"}
}
pdf4tcllib::table::render $pdf $x $y $cols $data
```

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
pdf4tcllib::form::sumLine    $pdf $ctx y {30 200 50 80} "Total:" ""
```

Note: `addForm` does not support CID fonts. The `form` namespace uses
Helvetica; only WinAnsi characters are reliable in form fields.


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

## License

BSD 2-Clause License. See [LICENSE](LICENSE) for details.

Copyright (c) 2026 Gregor (gregnix)
