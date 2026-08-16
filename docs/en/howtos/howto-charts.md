# How to put numbers on a page

Bar, line and pie charts with `pdf4tclchart`. Run the script beside this
file to produce the two pages it describes:

```
tclsh howto-charts.tcl [outdir]
```

---

## The plain case

```tcl
package require pdf4tclchart

set y [::pdf4tcllib::chart::bar $pdf $x $y $w 150 \
    {Jan 120 Feb 145 Mrz 98 Apr 160} -title "Revenue" -values 1 -format %.0f]
```

Labels and numbers, as flat pairs or as a list of `{label value}`. The four
numbers after `$pdf` are a box -- x, y, width, height -- and the call
returns the y below it, so charts stack like paragraphs.

`-values 1` writes the number at each bar. Do it: a bar chart says which
month was best, a bar chart with values says by how much.

---

## Two charts that can be compared

```tcl
::pdf4tcllib::chart::bar $pdf $x $y $half 140 {Q1 40 Q2 55 Q3 48 Q4 62} \
    -title "2025" -max 200
::pdf4tcllib::chart::bar $pdf [expr {$x + $half + 20}] $y $half 140 \
    {Q1 150 Q2 180 Q3 120 Q4 195} -title "2026" -max 200
```

**`-max` is the point of this section.** Without it each chart is scaled to
its own maximum, and a series of 40..62 gets bars exactly as tall as a
series of 120..195. Two charts side by side without a shared scale do not
compare anything -- they mislead, and they do it quietly.

---

## Several series

```tcl
::pdf4tcllib::chart::line $pdf $x $y $w 150 \
    {{2025 {Q1 40 Q2 55 Q3 48 Q4 62}}
     {2026 {Q1 150 Q2 180 Q3 120 Q4 195}}} -title "Two series"
```

The x labels come from the first series; the others are drawn against the
same positions. Every data point gets a dot, because a series of one value
would otherwise be invisible.

---

## Shares

```tcl
::pdf4tcllib::chart::pie $pdf $x $y $w 170 \
    {Nord 35 Sued 25 Ost 20 West 20} -legend 1
```

Use `-legend 1`. A slice without its name is a coloured wedge and nothing
else, and the legend also prints each share in percent.

A negative value is an error rather than a slice drawn backwards: a
negative part of a whole means nothing. So is a total of zero.

---

## Tagging: switch it on before the first page

```tcl
$pdf tagged 1 -lang en-GB
$pdf startPage
```

Not halfway through. Everything drawn before the call stays outside the
structure tree, and `getUntaggedCount` counts it from that moment on. The
first version of the accompanying script turned tagging on before its last
section and reported **35** loose drawing operations for the four charts
above; moving the call to the top made it **0**.

### Give the figure an alternate text

```tcl
::pdf4tcllib::chart::bar $pdf $x $y $w 150 {Jan 120 Feb 145 Mrz 98} \
    -title "Revenue" \
    -alt "Bar chart: revenue January to March, 120, 145 and 98 kEUR"
```

A chart is one `Figure` element with an alternate text, and everything
inside it is an artifact. `-alt` falls back to the title, and a title
rarely says what the picture shows -- "Revenue" is a heading, not a
description.

### And then print the numbers as well

```tcl
::pdf4tcllib::table::draw $pdf $x [expr {$y + 16}] \
    {{-header Monat} {-header "kEUR" -align right}} \
    {{Jan 120} {Feb 145} {Mrz 98}} -maxwidth $w
```

`getUntaggedCount` reports 0 with or without that table. It counts what is
unmarked, not what is understandable, and a figure with a one-line
description satisfies it completely -- while a reader who needs the
individual numbers still has none.

When the numbers matter, print them.

---

## See also

* [`../reference/pdf4tclchart.md`](../reference/pdf4tclchart.md) -- every
  option, and how the scaling is verified
* [`../reference/accessibility.md`](../reference/accessibility.md)
* [`howto-tagged-table.md`](howto-tagged-table.md) -- the table that goes
  under the chart
