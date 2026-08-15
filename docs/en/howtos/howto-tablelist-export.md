# How-to: export a tablelist widget

```bash
tclsh docs/en/howtos/howto-tablelist-export.tcl
```

Companion: [`howto-tablelist-export.tcl`](howto-tablelist-export.tcl). Needs
Tk, a display and the `tablelist` package; without them the script says so
and exits 0.

## The export

```tcl
package require pdf4tcltable
::pdf4tcllib::tablelist::render $pdf .tbl 50 70 -maxwidth 480
```

That is all. `render` delegates to `table::draw`, so the structure comes
with it -- measured on a four-row widget:

| | |
|---|---|
| `Table` | 1 |
| `TR` | 5 -- header plus four rows |
| `TH` | 3, each with `/Scope Column` |
| `TD` | 12 |

The widget's zebra stripes and grid lines become Layout artifacts. Nothing
extra to write.

## What leaves the widget is what is on screen

This is the reason the export exists: sorting, hidden columns and tree
indentation are display state, and the PDF shows the display, not the data
behind it.

Which cuts both ways. tablelist compares as strings unless told otherwise,
so a price column sorts `8.90` above `24.00`, and the export reproduces
that faithfully -- it is not the exporter's job to second-guess the widget:

```tcl
.tbl columnconfigure 2 -sortmode real     ;# what that column wants
.tbl sortbycolumn 2 -decreasing
```

Measured both ways: with the default the first data row is `Adapter 8.90`,
with `-sortmode real` it is `Case 24.00`. If the order in the PDF looks
wrong, look at the widget first.

## Useful options

| | |
|---|---|
| `-maxwidth` | scale to fit the text width |
| `-ctx` | page context, so long tables break pages |
| `-yvar`, `-pagevar` | variables updated as it goes |
| `-footer` | a footer row, from a widget or a plain list |
| `-formatted 1` | take the formatted cell text, as displayed |

Full reference: [`../pdf4tcltable.md`](../pdf4tcltable.md).

## The caption stays yours

```tcl
::pdf4tcllib::tag::begin $pdf Caption
$pdf text "Order items, sorted by price" -x 50 -y 50
::pdf4tcllib::tag::end $pdf
```

A table without a caption is legal and unhelpful: a reader arrives at a
grid of numbers with nothing to say what they are.
