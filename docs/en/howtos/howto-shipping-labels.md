# How-to: parcel labels

```bash
tclsh docs/en/howtos/howto-shipping-labels.tcl
```

Companion: [`howto-shipping-labels.tcl`](howto-shipping-labels.tcl). Builds
on [`howto-label-sheets.md`](howto-label-sheets.md), which explains the
sheet geometry.

Four A6 labels to a sheet (format 3427), each carrying sender, recipient,
carton count, tour and room for a barcode.

## Sort before expanding, not after

```tcl
set consignments [lsort -command {apply {{a b} {
    set c [string compare [dict get $a tour] [dict get $b tour]]
    if {$c != 0} { return $c }
    return [string compare [dict get $a city] [dict get $b city]]
}}} $consignments]
```

Labels come off the printer in one stack and get stuck on parcels in that
order. Sorting by tour means one driver's parcels arrive together; sorting
after the expansion would scatter the four cartons of one consignment
across the stack.

Then expand to one record per carton, as in the sheet how-to.

## What goes where, and how big

The layout is not decoration. Someone reads this from a metre away while
holding a parcel:

| | size | why |
|---|---|---|
| sender | 7 pt | the least important thing on the label, and the first thing people set in the biggest type |
| recipient name | 14 pt bold | what the label is for |
| street, town | 12 pt | |
| carton count `2 / 4` | 16 pt bold, right | checkable without picking the parcel up |
| tour and day | 10 pt bold, foot | what the sorter reads |
| consignment number | 8 pt, right | for the query, not for the driver |

The rule under the sender is an artifact. So is the barcode area -- a
barcode is a picture of data that is written out in full elsewhere on the
label, and a reader that announces it says nothing a person could use.

## The barcode

Not drawn here, because pdf4tcl has no barcode generator. The way in is
[tzint](https://sowaswie.de) -- a Tcl binding to libzint -- and its `bits`
mode:

```tcl
package require tzint
::tzint::Encode bits data "4711-2" -barcode code128
set w [dict get $data width]
foreach row [dict get $data bits] {
    # each row is a string of 0 and 1, one character per module
}
```

Draw the modules as rectangles. That keeps the code **vector**: sharp at
any print resolution, and smaller than an embedded raster. The `svg` and
`eps` modes are of no use here, since pdf4tcl embeds neither, and the file
modes would need libpng and a route through a Tk photo -- Tk being the
thing worth keeping out of a batch job.

Two things decide whether the result scans:

**Quiet zone.** White space either side of the code, ten module widths for
Code 128. A code drawn flush against a rule or the label edge does not
scan, and that failure looks like a printer problem.

**Module width.** The narrowest bar should not fall below about 0.25 mm on
a laser printer. At 105 mm label width that limits how much a Code 128 can
hold -- a consignment number fits comfortably, a full address does not.
Data Matrix or QR carry more in the same space if the scanner reads 2D.

## Printing

Print one sheet with `-frame 1` and hold it against a real one.

**At actual size.** "Fit to page" scales by a few per cent: invisible on
the first row, millimetres out by the last. This is the commonest reason
label sheets come out wrong.

## Tagging

Each label is a `Sect`, so a reader takes them one at a time instead of
meeting one long run of names and streets. Rules, shading and the barcode
area are artifacts.

Measured on the example: 3 consignments, 7 labels, 2 sheets,
`untagged: 0`.
