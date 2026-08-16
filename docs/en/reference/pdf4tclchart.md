# pdf4tclchart -- Bar, Line and Pie Charts

Data-driven and Tk-free, in the manner of `table::draw`: the caller hands
over labels and numbers, the module owns the geometry -- the scale, the
grid, where the bars sit.

```tcl
package require pdf4tclchart

set y [::pdf4tcllib::chart::bar $pdf $x $y $w 190 \
    {Jan 120 Feb 145 Mar 98 Apr 160} \
    -title "Revenue per month" -values 1]
```

**What this is not:** a plotting library. No logarithmic axes, no error
bars, no second y axis, no regression lines. It draws the three shapes a
report needs, and it draws them so the numbers can be read off the page.

---

## Data

Two forms, both accepted everywhere:

```tcl
{Jan 120 Feb 145 Mar 98}          ;# flat label/value pairs
{{Jan 120} {Feb 145} {Mar 98}}    ;# a list of pairs
```

An odd number of flat elements is an error, and so is a value that is not a
number -- the message names the label it belongs to, because "not a number"
without saying which one costs a search.

`line` also takes several series:

```tcl
{{2025 {Q1 100 Q2 130 Q3 120 Q4 175}}
 {2026 {Q1 140 Q2 120 Q3 165 Q4 190}}}
```

The x labels come from the first series; the others are drawn against the
same positions.

---

## Commands

All take a box: `pdf x y w h data ?option value ...?`. `y` counts downwards
as everywhere else in this library, and every command returns the y below
the chart, so charts stack the way paragraphs do.

### `bar pdf x y w h data ?options?`

Vertical bars, one colour per bar from the palette. Negative values are
drawn below the zero line, which is placed on the scale rather than at the
bottom of the box.

### `line pdf x y w h data ?options?`

One or several series, with a dot at every data point -- without the dots a
single value would be invisible.

### `pie pdf x y w h data ?options?`

Slices clockwise from twelve o'clock, percentages computed from the sum. A
negative value is an error: a slice of a whole cannot be negative. So is a
total of zero.

### `legend pdf x y pairs opts ?-total N?`

The legend `pie -legend 1` uses. Colour swatch, label, and the share in
percent when `-total` is given.

### `niceScale min max ?ticks?`

Returns `{min max step}` rounded to something a reader can divide: 137
becomes 150, not 137. The axis of a report is read, not measured, and a
grid line at 137 helps nobody.

### `configure ?option value ...?`

Read or set the defaults.

---

## Options

| option | default | |
|---|---|---|
| `-title` | `{}` | above the plot area |
| `-titlesize` | 11 | |
| `-labelsize` | 8 | axis and category labels |
| `-valuesize` | 8 | the numbers drawn by `-values` |
| `-values` | 0 | write the value at each bar |
| `-format` | `%g` | format for every number drawn |
| `-color` | `{}` | one colour for all bars/series |
| `-colors` | `{}` | a list, used in turn |
| `-grid` | 4 | number of grid lines; 0 for none |
| `-gridcolor` | light grey | |
| `-axiscolor` | dark grey | |
| `-min` `-max` | `{}` | override the scale |
| `-legend` | 0 | `pie` only |
| `-alt` | `{}` | alternate text for the tagged figure; falls back to `-title` |

### The palette

Six colours with **distinct lightness**, not just distinct hue. A chart
that only works in colour is half a chart -- these stay apart when the page
is printed in grey.

---

## Tagging

With `$pdf tagged 1`:

* the chart is one `Figure` element with an alternate text (`-alt`, or the
  title)
* everything inside is a `Layout` artifact -- the grid, the bars, the axis
  labels

That is the honest markup. A bar chart is a picture of numbers, and a
reader gets the figure and its description rather than a scattering of
loose text. If the numbers themselves matter to a reader, put them in a
table as well -- `getUntaggedCount` reports 0 either way, and that is
exactly the limit of what it can tell you.

---

## Measured

From the test suite, read back out of the uncompressed content stream:

```
data          120    145     98    160
bar height  86.52 104.55  70.66 115.36
ratio      0.7210 0.7210 0.7210 0.7210
```

The ratio being constant is the point: a scale that swaps two bars, shifts
the zero line or gets the span wrong breaks it. Also checked: bars come in
data order, a bigger value gives a taller bar, a negative value is drawn
below the zero line, and each further data point adds exactly one line
segment.

---

## See also

* [`table-draw.md`](table-draw.md) -- the same data, as a table
* [`API.md`](API.md) -- `drawing::`, on which this is built
* [`accessibility.md`](accessibility.md) -- what `Figure` and `-alt` buy
