# pdf4tcltemplate -- Documents from a Template

A delivery note, a quotation, an invoice, a letter: a few blocks at fixed
places, a table that runs over as many pages as it needs, and a few blocks
that follow the table wherever it ends. This module draws such a document
from two dicts.

```tcl
package require pdf4tcltemplate

set pdf [::pdf4tcl::new %AUTO% -paper a4]
::pdf4tcllib::template::render $pdf $layout $data
$pdf write -file note.pdf
```

The commands live in `::pdf4tcllib::template`.

`layout` is the template: where each block sits and how it looks, in
millimetres. It is what a designer edits and a program stores per document
type. `data` says
what each block shows, keyed by block id, and changes with every document.

---

## The module computes nothing

Totals, prices, dates and numbers arrive as finished text. The module
places, wraps and breaks pages. A program that prints amounts keeps one
place where they are computed, and the PDF cannot disagree with it.

---

## The layout

```tcl
set layout {
    paper a4  margin 20  size 10
    theme {accent {0.15 0.25 0.55} muted {0.4 0.4 0.4}}
    blocks {
        sender  {x 20 y 45 w 85 size 7 color muted}
        address {x 20 y 50 w 85 size 11 list 1}
        refs    {type pairs x 125 y 50 w 65 labelw 30 size 9}
        title   {x 20 y 95 w 170 size 15 bold 1 color accent
                 text "Delivery note {number}"}
        items   {type table x 20 y 108 w 170 size 9 zebra 1
                 cols {{key pos title Pos w 12 align right} {key text title Item}
                       {key qty title Qty w 22 align right}}}
        closing {x 20 y 0 w 170 gap 8}
        foot    {x 20 y 282 w 170 size 8 color muted page all align center
                 text "Page {page} of {pages}"}
    }
}
```

| key | default | |
|---|---|---|
| `paper` | `a4` | `a4`, `a5`, `letter` or `{width height}` in mm |
| `margin` | 20 | mm; default `x` and `w` of blocks that give none |
| `top` | `margin` | mm; where the flow continues on a new page |
| `bottom` | page height − `margin` | mm; where the flow stops |
| `size` | 10 | default font size in points |
| `theme` | | colour names → `{r g b}` |
| `blocks` | | block id → block, drawn in this order |

The block dict is the one of `tclutils::tulayout` and
`tkutils::tkulayoutcanvas`: `x y w h show`, and `y 0` (or `lockedY 1`)
for a block in the flow. A layout made with that designer can be drawn
here; neither package is needed.

### Blocks

| key | default | |
|---|---|---|
| `type` | `text` | `text`, `pairs`, `table`, `image`, `rule` |
| `x` `y` `w` `h` | | mm from the top left; `y 0`: in the flow |
| `show` | 1 | 0 hides the block |
| `page` | `first` | `first`, `all`, `rest` (pages 2 and on), `last`; not `first` needs a fixed `y` |
| `gap` | 0 | mm above a block in the flow |
| `size` | layout `size` | points |
| `bold` | 0 | |
| `color` | `text` | a theme name or `{r g b}`; `text`, `muted`, `rule`, `accent` have defaults |
| `align` | `left` | `left`, `right`, `center` |
| `leading` | 1.3 × size | line height in points |
| `field` | the block id | data key the block shows |
| `text` | | shown when the data has no value; `{key}` is replaced from the data, `{page}` and `{pages}` by the page numbers |

`text` blocks: `list 1` takes the value as a list of lines and drops empty
ones (an address without its second line). A newline in the value starts a
new line -- it never reaches the PDF as a character, where it would be a
missing glyph and break PDF/A.

`pairs` blocks: the value is `label value label value ...`; labels in the
first `labelw` mm, values beside them. Pairs with an empty value are left
out (`skipempty 0` keeps them).

`table` blocks: `cols` is a list of columns, each a key or
`{key k title t w mm align a}`. Columns without `w` share what is left of
the block width. The value is a list of rows, each a dict with the column
keys or a list in column order. A cell wraps inside its column, a row never
splits, the head repeats on every page. `header 0` drops the head,
`zebra 1` shades every second row, `rule` is the colour of the lines.

`image` blocks: the value is a file (PNG, JPEG). It is fitted into
`w × h` with its aspect kept, along the width as `align` says. A full-page
image at `x 0 y 0` with `page all`, first in the order, is a letterhead.

`rule` blocks: a line across `w` at `y`; `size` is its width in points.

### The flow

A block with a fixed `y` sits where it says. A block in the flow starts
`gap` mm below the block before it in the order -- usually the table, which
ends wherever its rows end. When it does not fit above `bottom`, a short
block moves to the next page as a whole; a long text block breaks between
lines.

---

## Commands

### `render pdf layout data ?option value ...?`

Draws the document. Returns a dict: `pages` (number of pages) and `y` (mm
below the last block).

| option | default | |
|---|---|---|
| `-font` | pdf4tcllib's sans face | font for normal text |
| `-fontbold` | its bold face, else `-font` | font for bold text |
| `-startpage` | 1 | render opens the first page and closes the last; 0 when the caller has a page open |
| `-newpage` | | script run after each page break, in the caller's scope |

The document may use any `-unit`; positions come out the same. It must use
`-orient 1` (y from the top), which is the pdf4tcl default.

`{pages}` needs the number of pages before the first one is drawn. When a
layout uses it, `render` first draws into a throw-away document with the
same paper, unit and fonts and counts.

### `check layout`

Returns the layout with defaults filled in, or raises
`{PDF4TCLLIB TEMPLATE <kind>}`: `LAYOUT`, `PAPER`, `BLOCK`, `TYPE`, `VALUE`.
`render` raises `OPTION`, `ORIENT` and `DATA` besides.

### `blockOrder layout`, `paperSize paper`

The block ids in drawing order; width and height of a paper in mm.

---

## Fonts and PDF/A

Pass fonts that the document embeds when it has to be PDF/A: the 14
standard fonts have no font program and are not allowed there. In a
document that another library opens -- an e-invoice wrapper, for
instance -- hand over the fonts that library loaded:

```tcl
::pdf4tcllib::template::render $pdf $layout $data -font $normal -fontbold $bold
```

With `$pdf tagged 1` text blocks become `P`, tables `Table`/`TR`/`TH`/`TD`,
lines and images artifacts. `getUntaggedCount` stays 0.

---

## Not covered

- Cells spanning columns, totals rows inside the table: put totals in a
  `pairs` block in the flow.
- A block taller than a page, other than a text block.
- Images other than what `addImage` reads; a PDF as letterhead must be
  turned into an image first.
