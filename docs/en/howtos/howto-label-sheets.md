# How-to: label sheets (Zweckform, Avery)

```bash
tclsh docs/en/howtos/howto-label-sheets.tcl
```

Companion: [`howto-label-sheets.tcl`](howto-label-sheets.tcl). Needs
`package require pdf4tcllabels`.

## The idea

The module owns the geometry -- sheet format, rows and columns, margins,
pitch, page breaks, and where on a part-used sheet to start. What goes
*on* a label is written once, as a script:

```tcl
package require pdf4tcllabels

set sheets [::pdf4tcllib::labels::render $pdf 3474 $labels {x y w h rec} {
    $pdf text [dict get $rec name] -x [expr {$x + 10}] -y [expr {$y + 20}]
} -start 2 -frame 1]
```

`x` and `y` are the label's top left corner in points, `w` and `h` its
size, `rec` one element of your list. Inside the script everything is
ordinary pdf4tcl.

## Sheet formats

```tcl
::pdf4tcllib::labels::sheets      ;# 3427 3474 3475 3483 4737
::pdf4tcllib::labels::sheet 3474  ;# geometry as a dict, in points
```

| name | labels | size | note |
|---|---|---|---|
| 3474 | 24 (3 x 8) | 70 x 37 mm | no gaps, no margins |
| 3475 | 21 (3 x 7) | 70 x 42.3 mm | |
| 3483 | 15 (3 x 5) | 70 x 50.8 mm | |
| 3427 | 4 (2 x 2) | 105 x 148 mm | A6 |
| 4737 | 27 (3 x 9) | 63.5 x 29.6 mm | with gaps and margins |

The pitch is stored per format rather than derived from the label size,
because some sheets have gaps and some do not. Guessing that from the
numbers is how the last row ends up half a millimetre out.

Adding a format is five numbers in the `SHEETS` array. Take them from the
box, not from a ruler.

## "Karton 1 von 4"

Keep one record per consignment and expand to one per label. Then the
drawing script never counts anything:

```tcl
set labels {}
foreach c $consignments {
    set n [dict get $c cartons]
    for {set i 1} {$i <= $n} {incr i} {
        dict set c carton $i
        dict set c of     $n
        lappend labels $c
    }
}
```

Three consignments of 4, 2 and 1 cartons give seven labels, and each one
knows which of how many it is.

## Part-used sheets

```tcl
... -start 2      ;# leave the first two positions empty
```

Nobody throws away a sheet with 22 labels left. `-start` is a parameter and
not something clever, because only the person holding the sheet knows how
many are gone.

## Your own formats

```tcl
::pdf4tcllib::labels::define buero {
    w 48.5  h 25.4  cols 4  rows 10  left 8.0  top 21.5
    pitchx 50.0  pitchy 25.4  paper a4  desc "office sheet, 40 per sheet"
}
```

Five numbers off the box and it is a format like any other. Nobody should
have to edit the module to use a sheet from the stationery cupboard. A
missing key is refused by name, not by a crash three procedures down.

## Printer offset -- the two numbers worth measuring once

Many printers place the image a millimetre or two off. On a borderless
sheet like 3474 that puts the first line half outside the label, and no
amount of care in the layout helps.

```tcl
# once per printer:
set pdf [::pdf4tcl::new %AUTO%]
::pdf4tcllib::labels::calibration $pdf 3474
$pdf write -file calibrate.pdf
```

Print that at actual size, lay it on a real sheet, read off how far the
grid sits from where it should be. Then, from now on:

```tcl
... -offsetx 2.0 -offsety 1.5      ;# millimetres
```

The calibration sheet carries a millimetre scale along the top and left
edge and an outline at every position. This is the difference between "the
labels are always a bit off" as a permanent state of affairs and two
numbers in a config file.

## Reprinting single positions

One label came out skewed, one is missing, and the rest of the sheet is
still good:

```tcl
... -only {5 9 20}
```

The positions are used in the order given, one per record, and nothing else
on the sheet is touched. `-only` and `-start` do different jobs: `-start`
skips a run at the beginning, `-only` names them outright.

Both refuse what cannot work -- a position outside the sheet, or fewer
positions than records.

## Text that has to fit

`Bundesanstalt für Immobilienaufgaben` is wider than 70 mm. Three
strategies, and all three are needed:

```tcl
# shrink until it fits, never below 6 pt
set size [::pdf4tcllib::labels::fitSize $pdf $font $name $maxW 12]

# break at spaces
foreach line [::pdf4tcllib::labels::wrap $pdf $name $maxW] { ... }

# shorten with an ellipsis
set ref [::pdf4tcllib::labels::ellipsize $pdf $reference $maxW]
```

Measured on that name in a 62 mm box: 211 pt wide at 12 pt, fits at 9.5 pt,
wraps to two lines, or shortens to `Bundesanstalt fuer Immobilien…`.

Use `ellipsize` for a reference or a note -- never for an address. Half a
street name is not a delivery.

All three measure in **points**, with `getStringWidth`. Never count
characters: under Tcl 8.6 a character above U+FFFF counts as two, and a
width computed from `string length` is wrong before anything is drawn.

## Getting it onto paper

```tcl
... -frame 1      ;# thin outline round every position
```

Print one sheet with frames and hold it against a real one before running a
batch.

**Print at actual size.** "Fit to page" or "shrink oversized pages" scales
by a few per cent, which is invisible on the first row and off by
millimetres by the last. This is the single most common reason label sheets
come out wrong, and no amount of care in the code helps against it.

The sheet formats put the first label at the very corner of the page for
3474 -- no margin at all. That is correct for that product and means the
PDF has content right at the paper edge; do not let a viewer "fit" it.

## Data from CSV, JSON or a database

The module takes a list; where it comes from is your business:

```tcl
# CSV
set fh [open orders.csv r]
fconfigure $fh -encoding utf-8
foreach line [split [read $fh] \n] {
    if {[string trim $line] eq ""} continue
    lassign [split $line ,] name street city tour cartons
    lappend consignments [dict create name $name street $street \
            city $city tour $tour cartons $cartons]
}
close $fh
```

For JSON use `rl_json` or `tcllib`'s `json`; for a database, `tdbc`. The
records are plain dicts, so anything that produces dicts fits.

Read text files as UTF-8 explicitly, as above -- otherwise Windows reads
them in the system encoding and the umlauts arrive wrong before pdf4tcl
ever sees them.

## Tagging

Each label is wrapped in a `Sect`: it is a unit of its own, and without it
every line of every label lands on the page as one loose run of text.
Change the type with `-tag`. The alignment frames are Layout artifacts.

Measured on the example: 7 labels, 7 `Sect`, `untagged: 0`.
