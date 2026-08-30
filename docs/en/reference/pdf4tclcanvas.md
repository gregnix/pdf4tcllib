# pdf4tclcanvas — Canvas export with a frame and a scale

**Package:** `pdf4tclcanvas 0.1`
**File:** `pdf4tclcanvas-0.1.tm`
**Requires:** `pdf4tcllib 0.6.3`, `pdf4tcl 0.9.4.25+`, Tk

Runnable companion: [`examples/advanced/71_canvas_place.tcl`](../../../examples/advanced/71_canvas_place.tcl) -- puts `place` and a raw `$pdf canvas` side by side and measures the difference (scale, structure tree, `fitPage`).

Places a canvas in a frame: to scale, anchored, and inside the structure
tree.

## What this does and what it does not

The drawing is not done here. `$pdf canvas` has done that for a long
time, for `tk::canvas`, `tkpath` and `tko::path`. Like
[`pdf4tcltable`](pdf4tcltable.md) and
[`pdf4tcltreeview`](pdf4tcltreeview.md) this is a thin adapter, and it
takes over the two things around it.

**The scale.** `$pdf canvas` takes `-width` and `-height` and pulls the
drawing onto them. Where the aspect ratio of the frame differs from that
of the drawing, it is distorted — exactly as `putImage` does with an
image, and just as silently. `place` computes the scale from the bounding
box and keeps the ratio.

**The structure tree.** A canvas export leaves holes. Measured on four
items — rectangle, oval, line, text — `$pdf canvas` alone leaves three
drawing operations outside the tree.

---

## Installation

```tcl
tcl::tm::path add /path/to/lib
package require pdf4tclcanvas
```

---

## Quick start

```tcl
package require Tk
package require pdf4tcl
package require pdf4tclcanvas
::pdf4tcllib::fonts::init

canvas .c -width 300 -height 200 -bg white
.c create rectangle 20 20 120 80 -fill lightblue
.c create text 140 160 -text "A diagram" -font {Helvetica 12}
pack .c
update idletasks

set pdf [pdf4tcl::new %AUTO% -paper a4 -margin 40]
$pdf tagged 1
$pdf startPage
::pdf4tcllib::canvas::place $pdf .c 0 0 400 200 -alt "The process"
$pdf endPage
$pdf write -file out.pdf
$pdf destroy
```

---

## place

```tcl
::pdf4tcllib::canvas::place $pdf $c $x $y $w $h ?-option value ...?
```

Returns the area actually used, `{x y w h}`, without the caption band.

| Option | Default | Meaning |
|---|---|---|
| `-fit` | contain | `contain` keeps the ratio, `stretch` is the old behaviour |
| `-anchor` | center | `nw n ne w center e sw s se` |
| `-alt` | {} | description; makes it a `Figure` |
| `-caption` | {} | caption under the drawing |
| `-captionH` | 14 | height of the caption band |
| `-fontsize` / `-font` | 9 / from `fonts::init` | for the caption |
| `-bbox` | {} | own bounding box instead of `all` |
| `-fontmap` / `-textscale` | {} | passed through to `$pdf canvas` |
| `-border` | 0 | draw a frame around the drawing |

### With `-alt` a Figure, without it an artifact

A drawing without a description is worth nothing to a reader — but a hole
in the tree is worse than decoration, so without `-alt` the export is
wrapped as an artifact. `getUntaggedCount` returns 0 either way; the
difference is whether a reader announces something.

A `-caption` doubles as the description when `-alt` is not given.

### The caption

Written inside the `Figure` as a `Caption`, so the tree says what the text
belongs to, and set **smaller rather than cut** when it is too wide —
see [`text::fitSize`](API.md#textfitsize-and-textfits--shrink-rather-than-cut).

### An empty canvas

`$c bbox all` returns nothing then, which used to abort `$pdf canvas`.
The widget size is used instead: an empty drawing is not an error.

---

## fitPage

```tcl
::pdf4tcllib::canvas::fitPage $pdf $c $ctx ?-option value ...?
```

The common case: a diagram filling a page, with the margins from
`page::context`. Takes the same options as `place`; the frame is `SX`,
`SY`, `SW`, `SH` — the same values `table::draw` and `forms::` compute
with.

---

## Limits

- Only `-orient 1` is meaningful, as everywhere in this library; see
  [`table-draw.md`](table-draw.md#the-page-direction-063).
- `tools/geometry-check.tcl` reports canvas exports as drawing outside
  the page. Those are false alarms: the content is placed with a `cm`
  transformation the checker does not read.
- What `$pdf canvas` cannot export, this cannot either — the adapter adds
  no item types.
