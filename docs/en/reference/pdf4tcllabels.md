# pdf4tcllabels -- Label Sheets

Sheets of adhesive labels: address labels, shipping labels, shelf tickets.
The module owns the geometry -- how many labels fit, where each one sits,
where the next sheet begins -- and the caller writes, once, what goes on a
label.

```tcl
package require pdf4tcllabels

set pdf [::pdf4tcl::new %AUTO% -paper a4]
::pdf4tcllib::labels::render $pdf 3474 $addresses {x y w h rec} {
    $pdf setFont 10 [::pdf4tcllib::fonts::fontSans]
    $pdf text [dict get $rec name]   -x [expr {$x + 8}] -y [expr {$y + 20}]
    $pdf text [dict get $rec street] -x [expr {$x + 8}] -y [expr {$y + 34}]
}
$pdf write -file labels.pdf
```

Everything below was measured against the running module, not taken from
the source comments.

> **Howtos:** [`../howtos/howto-label-sheets.md`](../howtos/howto-label-sheets.md)
> (geometry, "1 of 4", data from CSV/JSON/DB) and
> [`../howtos/howto-shipping-labels.md`](../howtos/howto-shipping-labels.md)
> (A6 shipping label, sorting before fanning out, what belongs at what size).

---

## Sheet catalogue

| name | grid | per sheet | label (mm) | margin l/t | pitch x/y | paper |
|---|---|---|---|---|---|---|
| `3427` | 2 x 2 | 4 | 105.0 x 148.0 | 0.00 / 0.00 | 105.0 / 148.0 | a4 |
| `3474` | 3 x 8 | 24 | 70.0 x 37.0 | 0.00 / 0.00 | 70.0 / 37.0 | a4 |
| `3475` | 3 x 7 | 21 | 70.0 x 42.3 | 0.00 / 0.45 | 70.0 / 42.3 | a4 |
| `3483` | 3 x 5 | 15 | 70.0 x 50.8 | 0.00 / 21.50 | 70.0 / 50.8 | a4 |
| `4737` | 3 x 9 | 27 | 63.5 x 29.6 | 7.25 / 13.00 | 66.0 / 29.6 | a4 |

3427 is A6 -- the usual shipping label. 4737 (Avery) is the one format here
with gaps between the labels: its pitch is wider than the label.

**Pitch is stored per format, not derived from the label size.** Some sheets
have gaps and some do not, and guessing that from the numbers is how the
last row ends up half a millimetre out.

The catalogue is checked by `tests/test_labels.tcl`: every format must fit
its page in both directions. That test exists because 3475 did not -- its
top margin put the last row 3.6 mm past the edge of an A4 sheet.

**Before printing a run of a format you have not used here: print one sheet
and hold it against the real thing.** The numbers come off the box; paper
is the only measurement that counts.

---

## Commands

All commands live in `::pdf4tcllib::labels` and are exported.

### `sheets`

```tcl
::pdf4tcllib::labels::sheets
```

The known sheet names, sorted:
`3427 3474 3475 3483 4737` plus anything added with `define`.

### `sheet name`

```tcl
set geo [::pdf4tcllib::labels::sheet 3474]
```

The geometry of one sheet as a dict, **in points** -- ready to compute with.
An unknown name is an error that lists the known ones.

| key | |
|---|---|
| `name` `desc` `paper` | as in the catalogue |
| `cols` `rows` `perSheet` | grid; `perSheet` is `cols * rows` |
| `w` `h` | label size |
| `left` `top` | margin to the first label |
| `pitchx` `pitchy` | column and row pitch |
| `wmm` `hmm` `leftmm` `topmm` `pitchxmm` `pitchymm` | the same in millimetres |

Millimetres are for the box, points are for the page; both are in the dict
so neither side has to convert.

### `define name spec`

```tcl
::pdf4tcllib::labels::define my-sheet {
    w 48.5 h 25.4 cols 4 rows 10 left 8.0 top 21.5
    pitchx 50.0 pitchy 25.4 paper a4 desc "from the stationery cupboard"
}
```

Adds or replaces a format at run time, in millimetres. `w h cols rows left
top pitchx pitchy` are required -- a missing one is an error naming it.
`paper` defaults to `a4`, `desc` to the name. Nobody should have to edit the
module to use a sheet from the cupboard.

### `place geo idx`

```tcl
lassign [::pdf4tcllib::labels::place $geo 0] x y     ;# -> 0.0 0.0
```

Top left corner of label `idx` (0-based) in points, counting left to right
and top to bottom. `render` calls this for you; it is public for laying out
something by hand.

`idx` outside `0 .. perSheet-1` is an error. It has to be: until this check
existed, position 24 of a 24-per-sheet form answered with the ninth row of
an eight-row sheet, and -1 with a row above the page -- both silently.

### `render pdf name records argSpec script ?options?`

```tcl
set sheets [::pdf4tcllib::labels::render $pdf 3474 $records {x y w h rec} {
    ...
} -start 2 -offsetx 2.0 -frame 1]
```

Draws one label per element of `records` and returns **the number of sheets
written**. Pages are opened and closed by `render`; do not call `startPage`
around it.

* `argSpec` names five variables -- `{x y w h record}`. Any other length is
  an error. `x y` are the label's top left corner, `w h` its size, all in
  points; `record` is the element as given.
* `script` runs in the caller's scope with those five set, once per record.

| option | default | |
|---|---|---|
| `-start N` | 0 | leave the first N positions empty -- what a part-used sheet needs. Only the person holding the sheet knows how many are gone. |
| `-only {i j ...}` | `{}` | use exactly these positions, for reprinting single labels onto a part-used sheet. Must name at least as many positions as there are records. |
| `-offsetx MM` `-offsety MM` | 0.0 | printer offset in millimetres, see `calibration` |
| `-frame 0\|1` | 0 | thin outline round every position, for aligning on paper. Never for production. |
| `-tag TYPE` | `Sect` | structure type each label is wrapped in when tagging is on |

An unknown option is an error listing the known ones.

Measured, sheet 3474 with 24 positions:

| records | sheets |
|---|---|
| 1 | 1 |
| 24 | 1 |
| 25 | 2 |
| 49 | 3 |

**Tagging.** With `$pdf tagged 1`, each label is wrapped in one structure
element (`Sect` by default), because one label is one unit of content --
without it every line of every label lands in the page as a loose run of
text. Measured on a tagged run: `/Document`, `/Sect`, `/P` in the structure
tree and `getUntaggedCount` = 0.

### `calibration pdf name`

```tcl
::pdf4tcllib::labels::calibration $pdf 3474
```

Writes one sheet with a millimetre scale along the top and left edge and an
outline at every label position. Print it **at actual size**, lay it on a
real sheet, read off how far the grid sits from where it should, and pass
those two numbers as `-offsetx`/`-offsety` from then on.

Printer offset is the rule, not the exception -- one to two millimetres is
usual, and on a borderless sheet like 3474 that puts the first row half
outside the label. Two numbers, measured once per printer, settle it
permanently.

> "Fit to page" scales by a few percent: invisible in the first row,
> millimetres out by the last. It is the most common reason for a skewed
> sheet, and no code helps against it.

---

## Fitting text into a label

Three helpers, all needing a `pdf` object because they measure with
`getStringWidth` -- widths in points, never in characters. Under Tcl 8.6 a
character beyond U+FFFF counts twice.

### `fitSize pdf font text maxW size ?min?`

Shrinks the font size in 0.5 pt steps until the text fits, but not below
`min` (default 6). Returns the size to use.

```tcl
fitSize $pdf Helvetica "Kurz" 200.0 10                    ;# -> 10
fitSize $pdf Helvetica "Ein deutlich zu langer Text" 60.0 10  ;# -> 6.0
```

The second case is the honest one: at the minimum it stops shrinking and
the text still does not fit. Check the result if that matters.

### `wrap pdf text maxW`

Breaks at spaces into lines no wider than `maxW`, returns the list of lines.

```tcl
wrap $pdf "Musterstrasse 12 in einer langen Ortschaft" 90.0
# -> {Musterstrasse 12 in einer langen} Ortschaft
```

A single word that is too long stays on its own line rather than being cut.
A broken postcode is worse than a wide one.

### `ellipsize pdf text maxW ?tail?`

Shortens to fit, ending in `tail` (an ellipsis by default).

```tcl
ellipsize $pdf "Eine Bemerkung, die zu lang ist" 60.0
# -> "Eine Bemerkung, di…"
```

For fields where the exact value does not matter to the reader -- a
reference, a note. **Never for an address:** half a street name is not a
delivery.

---

## Practical notes

**Sort before fanning out.** Labels come off the printer as a stack. Sorted
by round, one driver's consignments lie together; sorted the other way, the
cartons of one consignment do.

**Barcodes** are not part of this module. The way in is tzint's `bits` mode
-- translate the module matrix into rectangles, which keeps the code
vectorial. Quiet zone ten module widths for Code 128, narrowest bar not
below 0.25 mm. A code across a fold is not read, and the failure looks like
a printer problem.

---

## See also

* [`API.md`](API.md) -- pdf4tcllib, including `fonts::init` and
  `units::mm`
* [`accessibility.md`](accessibility.md) -- what tagging does and does not
  guarantee
