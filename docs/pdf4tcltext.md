# pdf4tcltext — Tk Text Widget PDF Export

**Package:** `pdf4tcltext 0.1`  
**File:** `pdf4tcltext-0.1.tm`  
**Requires:** `pdf4tcllib 0.2`, `pdf4tcl 0.9.4.25+`, Tk

Exports a Tk `text` widget to a formatted PDF, preserving fonts, colors,
underline, strikethrough, indentation, and spacing. Based on `$t dump -all`
which delivers the complete tag structure as a processable triplet stream.

---

## Installation

```tcl
tcl::tm::path add /path/to/lib
package require pdf4tcltext
```

`pdf4tcltext` automatically loads `pdf4tcllib 0.2` as a dependency.
The namespace `pdf4tcllib::textwidget` remains available alongside the
`pdf4tcltext` alias.

---

## Quick Start

```tcl
package require Tk
package require pdf4tcltext

# Build text widget with tags
text .t -width 60 -height 10 -wrap word -font {Helvetica 11}
pack .t -fill both -expand 1

.t tag configure h1   -font {Helvetica 16 bold} -foreground "#1a2f5a" \
    -spacing1 8 -spacing3 4
.t tag configure bold -font {Helvetica 11 bold}
.t tag configure code -font {Courier 10} -background "#f0f0f0"
.t tag configure link -foreground "#0044aa" -underline 1

.t insert end "Report 2026\n" h1
.t insert end "This is a "
.t insert end "critical" bold
.t insert end " note about "
.t insert end "pdf4tcltext" code
.t insert end ". See "
.t insert end "github.com/gregnix" link
.t insert end " for details.\n"

# Export to PDF
set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

pdf4tcltext::render $pdf .t [dict get $ctx left] [dict get $ctx top] \
    -maxwidth [dict get $ctx text_w] \
    -ctx      $ctx

$pdf endPage
$pdf write -file output.pdf
$pdf destroy
```

---

## Command

### pdf4tcltext::render

```tcl
pdf4tcltext::render pdf tw x y ?option value ...?
```

Exports the text widget content starting at position (`x`, `y`).

Alias for `pdf4tcllib::textwidget::render`.

**Returns:** new Y position below the rendered text.

---

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `-maxwidth W` | 480 | Content width in points |
| `-fontsize N` | 10 | Default font size in points |
| `-fontfamily S` | Helvetica | Default font family |
| `-linespacing N` | 2 | Extra line spacing in points |
| `-skipelided 0/1` | 1 | Skip text with `-elide 1` tags |
| `-skipinternal 0/1` | 1 | Ignore internal marks (`sel`, `insert`) |
| `-ctx dict` | — | `page::context` dict for orient-aware layout |
| `-yvar name` | — | Variable to receive the new Y position |

---

## Supported Tag Options

### Font

```tcl
$t tag configure h1   -font {Helvetica 16 bold}
$t tag configure code -font {Courier 10}
$t tag configure em   -font {Helvetica 11 italic}
```

Accepted font formats:

```tcl
# List format
$t tag configure t1 -font {Helvetica 12 bold italic}

# Options format
$t tag configure t2 -font [list -family Helvetica -size 12 -weight bold]

# Named font
font create myFont -family Helvetica -size 12 -weight bold
$t tag configure t3 -font myFont
```

> **Tip:** For font family names containing spaces (e.g. `DejaVu Sans`),
> use named fonts or the options format to avoid ambiguous parsing.

Font mapping to standard PDF fonts:

| Tk family | PDF font |
|-----------|----------|
| Helvetica, Arial, sans-serif | Helvetica |
| Times, Georgia, serif | Times-Roman |
| Courier, Consolas, *Mono* | Courier |
| + bold | -Bold |
| + italic / oblique | -Oblique / -Italic |
| + bold italic | -BoldOblique / -BoldItalic |
| other | Helvetica (fallback) |

### Colors

```tcl
$t tag configure heading  -foreground "#1a2f5a"
$t tag configure highlight -background "#fffacc"
$t tag configure warning  -foreground "#8b4500" -background "#fff0d0"
```

All Tk color formats are supported: `#RRGGBB`, `#RGB`, named colors.

> **Note:** Named colors require a visible Tk window (`winfo rgb`).
> Use hex colors when the main window is withdrawn.

### Underline and Strikethrough

```tcl
$t tag configure link    -underline  1
$t tag configure deleted -overstrike 1
```

Both are rendered as PDF lines in the same color as the text.

### Indentation and Spacing

```tcl
$t tag configure quote -lmargin1 30 -spacing1 6 -spacing3 4
$t tag configure code  -lmargin1 20
```

| Option | Description | Unit |
|--------|-------------|------|
| `-lmargin1` | Left indent (first line) | pixels × 0.75 → points |
| `-spacing1` | Space before paragraph | pixels × 0.75 → points |
| `-spacing3` | Space after paragraph | pixels × 0.75 → points |

### Hidden Text

```tcl
$t tag configure elided -elide 1
$t insert end "HIDDEN" elided    ;# skipped in PDF by default
```

Set `-skipelided 0` to include elided text in the export.

---

## Tag Priority

The text widget resolves conflicts between overlapping tags by priority:
tags created later have higher priority. The exporter honours this via
`tag names` ordering.

```tcl
$t tag configure h1  -foreground "#1a2f5a"
$t tag configure red -foreground "#cc0000"   ;# higher priority

# Explicit control:
$t tag raise h1 red    ;# h1 above red
$t tag lower red       ;# red to bottom
```

Multiple tags active on the same text segment are merged — higher
priority properties override lower priority ones.

---

## Overlapping Tags

```tcl
# Multiple tags applied simultaneously -- fully supported
$t insert end "Bold and red text" {bold red}

# Overlapping tag ranges
$t tag add bold "1.0"  "1.20"
$t tag add red  "1.10" "1.30"
# Characters 10-20: both bold and red active
```

Each text segment is rendered with the merged style of all active tags.

---

## Limitations

| Feature | Status |
|---------|--------|
| `-offset` (superscript / subscript) | Not implemented |
| `-justify center/right` | Not implemented — all text left-aligned |
| `-wrap none/char` | No pixel-based line breaking |
| `-spacing2` (inter-line spacing) | Not implemented — use `-linespacing` |
| Embedded windows (`-window`) | Placeholder `[Widget]` |
| Embedded images (`-image`) | Placeholder `[Image: name]` |
| `-relief`, `-borderwidth` | No PDF equivalent |
| Selection highlighting | Interactive only |
| Page breaks | Manual — see below |

---

## Page Breaks

The exporter renders into a single continuous column. For multi-page
content, split the text widget range manually or track Y position:

```tcl
set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
set ybot [dict get $ctx bottom]

$pdf startPage
set y [dict get $ctx top]

pdf4tcltext::render $pdf .t [dict get $ctx left] $y \
    -maxwidth [dict get $ctx text_w] \
    -ctx      $ctx \
    -yvar     y

# If content overflowed the page, start a new one
# (split content across multiple text widgets, or
#  use a fixed chunk size and renderRange on each)
if {$y > $ybot} {
    # content exceeded page -- consider splitting at logical boundaries
}

$pdf endPage
$pdf write -file output.pdf
$pdf destroy
```

For structured multi-page documents, populate separate text widgets
per section and export each on its own page.

---

## Common Mistakes

**Font with spaces in family name:**
```tcl
# AMBIGUOUS -- parser may misinterpret "Sans" as size
$t tag configure h1 -font {DejaVu Sans 16 bold}

# SAFE -- named font
font create h1Font -family "DejaVu Sans" -size 16 -weight bold
$t tag configure h1 -font h1Font
```

**`winfo rgb` fails with withdrawn window:**
```tcl
# If . is withdrawn, use hex colors instead of named colors
$t tag configure warning -foreground "#cc0000"   ;# safe
$t tag configure warning -foreground "red"        ;# needs visible window
```

**Pixel vs. points for margins:**

The text widget uses pixels for `-lmargin1` / `-spacing`. The exporter
converts with factor 0.75 (96 DPI approximation):
40 pixels → 30 points. Adjust tag values accordingly if margins look off.

**`update idletasks` before export:**

Always render the widget before exporting so that tag geometry is
fully computed:
```tcl
pack .t
update idletasks
pdf4tcltext::render $pdf .t $x $y ...
```

---

## Checklist

```
[ ] Use wish (not tclsh) -- winfo rgb requires Tk
[ ] update idletasks before render
[ ] Hex colors when main window is withdrawn
[ ] Font families with spaces: use named font or options format
[ ] -lmargin1 / -spacing values are pixels (x0.75 -> points in PDF)
[ ] Set pdf4tcl -orient true explicitly
[ ] Use page::context for layout constants
[ ] Elided text is skipped by default (-skipelided 0 to include)
[ ] Embedded windows/images appear as placeholders
```

---

## See Also

- `docs/API.md` — full pdf4tcllib API reference
- `docs/pdf4tcltable.md` — tablelist widget export
- `examples/advanced/57_textwidget_pdf.tcl` — complete demo
