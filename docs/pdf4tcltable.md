# pdf4tcltable — Tablelist Widget PDF Export

**Package:** `pdf4tcltable 0.1`  
**File:** `pdf4tcltable-0.1.tm`  
**Requires:** `pdf4tcllib 0.2`, `pdf4tcl 0.9.4.25+`, `tablelist_tile` (Csaba Nemethi)

Exports a Tk `tablelist` widget directly to a formatted PDF table.
Reads cell values, colors, fonts, and tree structure from the widget API —
not from the internal text widget.

> **Note:** tablelist has no built-in CSV or PDF export. `dumptostring` /
> `dumptofile` is a proprietary save/restore format, not an export format.

---

## Installation

```tcl
tcl::tm::path add /path/to/lib
package require pdf4tcltable
```

`pdf4tcltable` automatically loads `pdf4tcllib 0.2` as a dependency.
The namespace `pdf4tcllib::tablelist` remains available alongside the
`pdf4tcltable` aliases.

---

## Quick Start

```tcl
package require Tk
package require tablelist_tile
package require pdf4tcltable

# Build tablelist
tablelist::tablelist .tbl \
    -columns {8 "No." right  20 "Name" left  12 "Price" right} \
    -stripebackground "#f0f4ff"
pack .tbl -fill both -expand 1
.tbl insert end {1 "Widget A" 29.99}
.tbl insert end {2 "Widget B"  9.99}
update idletasks

# Export to PDF
set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set y [expr {[dict get $ctx top] + 10}]

pdf4tcltable::render $pdf .tbl [dict get $ctx left] $y \
    -maxwidth [dict get $ctx text_w] \
    -ctx      $ctx \
    -yvar     y

$pdf endPage
$pdf write -file output.pdf
$pdf destroy
```

---

## Commands

### pdf4tcltable::render

```tcl
pdf4tcltable::render pdf tbl x y ?option value ...?
```

Exports the entire tablelist widget starting at position (`x`, `y`).

Alias for `pdf4tcllib::tablelist::render`.

### pdf4tcltable::renderRange

```tcl
pdf4tcltable::renderRange pdf tbl x y ?option value ...?
```

Exports a row range — use this for multi-page tables with manual page
breaks. All options from `render` apply, plus `-firstrow` and `-lastrow`.

Alias for `pdf4tcllib::tablelist::renderRange`.

---

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `-maxwidth W` | 480 | Table width in points |
| `-fontsize N` | 9 | Font size in points |
| `-rowheight N` | 0 | Row height (0 = auto: 1.8 × fontsize) |
| `-zebra 0/1` | 1 | Zebra stripes (color from widget) |
| `-border 0/1` | 1 | Draw cell borders |
| `-tree 0/1` | 1 | Export tree indentation |
| `-indentW N` | 12 | Indentation width per level in points |
| `-formatted 0/1` | 1 | Use `getformatted` instead of `get` |
| `-headerbg {r g b}` | from widget | Header background color (0.0–1.0) |
| `-headerfg {r g b}` | from widget | Header text color |
| `-ctx dict` | — | `page::context` dict for orient-aware layout |
| `-yvar name` | — | Variable to receive the new Y position |
| `-firstrow N` | 0 | *(renderRange only)* First row, 0-based |
| `-lastrow N` | -1 | *(renderRange only)* Last row (-1 = end) |

---

## Colors

Cell, row, and zebra colors are read directly from the widget — no
manual configuration needed.

```tcl
# Row color
$tbl rowconfigure 3 -background "#ffe0e0" -foreground "#cc0000"

# Cell color and font
$tbl cellconfigure 3,2 -foreground "#003399" -font {Helvetica 9 bold}

# Global zebra stripes
$tbl configure -stripebackground "#f0f4ff"
```

**Priority** (higher overrides lower):

```
cell color  >  row color  >  zebra color  >  no background (white)
```

All Tk color formats are supported: `#RRGGBB`, `#RGB`, named colors
(e.g. `lightblue`, `DarkSlateGray`).

> **Note:** Named colors require a visible Tk window
> (`winfo rgb` fails in a withdrawn or headless window).
> Use hex colors if no display is available.

---

## Column Widths

Column widths are derived from the tablelist `-width` setting
(character count) and scaled proportionally to `-maxwidth`:

```
pdf_width = (char_width / total_char_width) * maxwidth
```

`-width 0` (auto) is treated as a minimum of 5 characters.
Negative `-width` values (tablelist max-width) are treated as their
absolute value. Hidden columns (`-hide 1`) are excluded.

---

## -formatcommand

When a column has `-formatcommand` set, `getformatted` is used
automatically (controlled by `-formatted 1`, the default).

```tcl
proc fmtPrice {val} {
    if {![string is double -strict $val]} { return $val }
    return [format "%.2f EUR" $val]
}
$tbl columnconfigure 2 -formatcommand fmtPrice
```

> **Important:** tablelist calls `-formatcommand` with exactly **one**
> argument (the cell value). Define the proc with one parameter.
> Use a prefix list for additional context:
> ```tcl
> proc fmtWith {prefix val} { return "$prefix: $val" }
> $tbl columnconfigure 2 -formatcommand {fmtWith EUR}
> ```

---

## Tree Mode

```tcl
set cat [$tbl insertchild root end {"Electronics" "" ""}]
$tbl rowconfigure $cat -font {Helvetica 9 bold}
$tbl insertchild $cat end {"Laptop 15" "E-001" "899.99"}
$tbl insertchild $cat end {"Laptop 13" "E-002" "749.00"}

pdf4tcltable::render $pdf $tbl $x $y \
    -tree   1 \
    -indentW 14
```

Indentation per level = `max(0, depth - 1) * indentW`.
Root nodes (depth 0) and top-level children (depth 1) are not indented.

---

## Page Breaks

Use `renderRange` to split large tables across pages:

```tcl
set nrows [$tbl size]
set rh    [expr {1.8 * $fontsize}]   ;# approximate row height
set hdrH  $rh                        ;# header row

$pdf startPage
set y [dict get $ctx top]

set rowsPerPage [expr {int(([dict get $ctx bottom] - $y - $hdrH) / $rh)}]
set from 0

while {$from < $nrows} {
    set to [expr {min($from + $rowsPerPage - 1, $nrows - 1)}]

    pdf4tcltable::renderRange $pdf $tbl $lx $y \
        -maxwidth  $tw   \
        -fontsize  $fontsize \
        -firstrow  $from \
        -lastrow   $to   \
        -ctx       $ctx  \
        -yvar      y

    set from [expr {$to + 1}]
    if {$from < $nrows} {
        $pdf endPage
        $pdf startPage
        set y [dict get $ctx top]
    }
}
$pdf endPage
```

---

## Font Mapping

Tk font specifications are mapped to standard PDF fonts:

| Tk font | PDF font |
|---------|----------|
| `{Helvetica N}` | Helvetica |
| `{Helvetica N bold}` | Helvetica-Bold |
| `{Helvetica N italic}` | Helvetica-Oblique |
| `{Helvetica N bold italic}` | Helvetica-BoldOblique |
| `{Courier N}` or monospace | Courier |
| `{Courier N bold}` | Courier-Bold |
| `{Times N}` | Times-Roman |
| `{Times N bold}` | Times-Bold |
| other | Helvetica (fallback) |

For Unicode text (non-Latin characters): load a CIDFont via
`pdf4tcllib::fonts::init` before exporting.

---

## Embedded Cell Widgets

tablelist allows embedding Tk widgets (Checkbutton, Combobox, Spinbox,
Entry) in cells. The PDF export reads the cell value via `$tbl get` —
the embedded widget is not rendered visually. The stored value appears
as plain text:

| Widget type | PDF value |
|-------------|-----------|
| Checkbutton | `0` or `1` |
| Combobox | current text value |
| Spinbox / Entry | current text value |

---

## tablelist API Used

| Command | Purpose |
|---------|---------|
| `$tbl columncount` | Number of columns |
| `$tbl size` | Number of rows |
| `$tbl columncget N -title` | Column header text |
| `$tbl columncget N -align` | Alignment: left / right / center |
| `$tbl columncget N -width` | Width in characters |
| `$tbl columncget N -hide` | Column hidden? |
| `$tbl columncget N -formatcommand` | Format proc |
| `$tbl getformatted 0 end` | All rows with `-formatcommand` applied |
| `$tbl get 0 end` | All rows without formatting |
| `$tbl cellcget R,C -background/foreground/font` | Cell style |
| `$tbl rowcget R -background/foreground/font/hide` | Row style |
| `$tbl cget -stripebackground` | Global zebra color |
| `$tbl depth R` | Tree depth (for indentation) |

---

## Known Limitations

| Limitation | Reason |
|-----------|--------|
| Cell images (`-image`) | Tk image not auto-rasterized |
| Embedded windows (`-window`) | Tk widget not vectorizable |
| Multi-line cell text | Fixed row height — no auto-wrap |
| CIDFonts in cells | Only standard PDF fonts by default |
| Column tooltips | Tk-only, not in PDF |

---

## Common Mistakes

**`tabIdx1` not found** — `cellconfigure` called before `update idletasks`:
```tcl
foreach row $data { $tbl insert end $row }
update idletasks          ;# required before cellconfigure
for {set r 0} {$r < [$tbl size]} {incr r} {
    $tbl cellconfigure $r,2 -font {Helvetica 9 bold}
}
```

**`wrong # args` in `-formatcommand`** — tablelist passes exactly one
argument (the cell value). Define the proc with one parameter only.

**`winfo rgb` fails** — Named colors require a visible Tk window.
Run with `wish`, not `tclsh`. Ensure `.` is not withdrawn when
`cellconfigure` with named colors is called.

**`%,` in format string** — Tcl's `format` does not support `%,` for
thousands separator. Use a custom proc instead:
```tcl
proc fmtThousands {val} {
    # manual thousands formatting
    set s [format "%.2f" $val]
    # ... insert separators ...
    return $s
}
```

---

## Checklist

```
[ ] Use wish (not tclsh) -- winfo rgb requires Tk
[ ] Add tablelist to auto_path before package require
[ ] Insert all rows, then update idletasks, then cellconfigure
[ ] -formatcommand proc takes exactly 1 parameter (cell value)
[ ] Use list {} not {[...]} for paths in foreach
[ ] format "%.2f" not "%,.2f" (no thousands separator in Tcl format)
[ ] Set pdf4tcl -orient true explicitly
[ ] Use page::context for layout constants
[ ] Zebra color via [$tbl cget -stripebackground]
[ ] Filter hidden columns via columncget -hide
[ ] Tree indentation: max(0, depth-1) * indentW
```
