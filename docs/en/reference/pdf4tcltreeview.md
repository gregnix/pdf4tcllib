# pdf4tcltreeview — ttk::treeview PDF Export

**Package:** `pdf4tcltreeview 0.1`
**File:** `pdf4tcltreeview-0.1.tm`
**Requires:** `pdf4tcllib 0.6.3`, `pdf4tcl 0.9.4.25+`, Tk

Exports a `ttk::treeview` — as a table with the tree column indented, or
as an outline with a bookmark per node.

## Two procedures, not one option

A `ttk::treeview` is two things at once: a table with columns and a tree.
On screen you see both; in a PDF you have to choose, because the
structure tree knows no hybrid:

| | structure |
|---|---|
| table | `Table` / `TR` / `TD` |
| outline | `L` / `LI` / `LBody` |

Which one applies cannot be guessed from the widget — a treeview with
three value columns is a table, one with only the tree column is a list.
Hence `render` and `outline` rather than a switch.

Like [`pdf4tcltable`](pdf4tcltable.md) this is a thin adapter: it reads
the widget and delegates to [`::pdf4tcllib::table::draw`](table-draw.md),
which has done indentation since 0.3 through `-rowindent`.

---

## Installation

```tcl
tcl::tm::path add /path/to/lib
package require pdf4tcltreeview
```

---

## Quick start

```tcl
package require Tk
package require pdf4tcl
package require pdf4tcltreeview
::pdf4tcllib::fonts::init

ttk::treeview .tv -columns {menge preis} -show {tree headings}
.tv heading #0 -text "Artikel"
.tv heading menge -text "Menge"
.tv heading preis -text "Preis"
.tv column menge -anchor e
.tv column preis -anchor e

set a [.tv insert {} end -text "Schrauben" -values {100 4.90} -open 1]
.tv insert $a end -text "M6" -values {60 2.90}
.tv insert $a end -text "M8" -values {40 2.00}
pack .tv
update idletasks

set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf tagged 1
$pdf startPage
::pdf4tcllib::treeview::render $pdf .tv 40 60 -maxwidth 500
$pdf endPage
$pdf write -file tree.pdf
$pdf destroy
```

---

## render — the table reading

```tcl
::pdf4tcllib::treeview::render $pdf $tv $x $y ?-option value ...?
```

Draws what is on the screen: the tree column indented, the value columns
beside it. Returns the y position after the last row.

| Option | Default | Meaning |
|---|---|---|
| `-maxwidth` | 480 | width of the table in points |
| `-fontsize` | 9 | |
| `-rowheight` | 0 | 0 = derived from the font size |
| `-tree` | 1 | indent the tree column; 0 draws flat |
| `-all` | 0 | include closed branches |
| `-zebra` | 1 | alternating row background |
| `-border` | 1 | grid lines |
| `-indentW` | 12 | indent per level in points |
| `-ctx` | {} | page context from `page::context` |
| `-yvar` | {} | variable receiving the y after the table |
| `-pagevar` | {} | variable holding the page number |
| `-font` / `-boldfont` | {} | otherwise the fonts from `fonts::init` |
| `-summary` | {} | `/Summary` on the `Table` element |

**A closed branch stays closed.** The PDF shows what was on the screen;
`-all 1` takes everything.

Column widths come from the widget in pixels and are scaled to
`-maxwidth`, so the proportions are kept. The alignment comes from the
column's `-anchor`.

### The tree column

`ttk::treeview` keeps the tree in column `#0`, separate from the value
columns: `-text` is in `#0`, `-values` in the rest. With `-show headings`
alone there is no tree column, and the export is an ordinary table —
`-tree` then has no effect, because indenting the first *value* column
would state something about the data that the widget does not.

---

## outline — the tree reading

```tcl
::pdf4tcllib::treeview::outline $pdf $tv $x $y ?-option value ...?
```

Draws the tree column alone as an indented list, with a bookmark per node
nested as deeply as in the widget — which makes the tree navigable in a
reader, something a table does not offer. Returns the y after the last
line.

| Option | Default | Meaning |
|---|---|---|
| `-fontsize` | 10 | |
| `-indentW` | 14 | indent per level in points |
| `-lineH` | 0 | 0 = 1.4 × font size |
| `-all` | 0 | include closed branches |
| `-bookmarks` | 1 | one bookmark per node |
| `-font` | {} | otherwise `fonts::fontSans` |
| `-yvar` | {} | variable receiving the y after the list |

```tcl
$pdf startPage
::pdf4tcllib::treeview::outline $pdf .tv 40 60 -all 1 -indentW 18
$pdf endPage
```

A node without `-text` falls back to the first value, so a treeview used
purely as a table still produces readable entries.

> **0.1:** `-bookmarks 1` produced no bookmark at all -- `bookmarkAdd` got
> the level as its first word, pdf4tcl raised, and the error was caught.
> Fixed in 0.1.1. A bookmark points to the page of its node.

---

## Tagged PDF

Both procedures leave a complete structure tree: `getUntaggedCount`
returns 0 after either of them. `render` produces `Table`/`TR`/`TD` with
`TH` for the header row, `outline` produces `L`/`LI`/`LBody`.

If you need both readings of the same data in one document, draw them on
separate pages — `Table` and `L` describe the same content differently,
and a reader would announce it twice.

---

## Limits

- Cell colors and per-item fonts are not read; the table is drawn in the
  configured fonts. `pdf4tcltable` does read them, because tablelist
  exposes them per cell.
- Images on items (`-image`) are ignored.
- A `rowspan` in the sense of the table module does not arise here: a
  treeview has one value per column and row.
