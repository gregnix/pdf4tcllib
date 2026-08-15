# How-to: a table a screen reader can navigate

```bash
tclsh docs/en/howtos/howto-tagged-table.tcl
```

Companion: [`howto-tagged-table.tcl`](howto-tagged-table.tcl).

## The short way

```tcl
$pdf tagged 1 -lang en-GB
::pdf4tcllib::table::simpleTable $pdf 50 60 {150 90 90} $rows -zebra 1
```

That is the whole of it. All three renderers -- `simpleTable`, `render` and
`draw` -- mark up what they draw:

- `Table` / `TR` / `TH` / `TD`
- header cells carry `/Scope Column`
- grid lines, zebra stripes and the header background become Layout
  artifacts

The header is the first row, the one `-header_bg` paints. Without that
option there is no header and every cell is a `TD`.

## Why the artifacts matter as much as the structure

Decoration announced as content is worse than no markup at all: a reader
reads the separators out between the numbers. Marking them keeps them off
the page as far as assistive technology is concerned, while they stay
visible to everyone else.

## Why `/Scope Column`

ISO 14289-1 clause 7.5 asks for it wherever the relation between header and
data cell cannot be read off the layout -- and with a single header row it
never can. Without the scope a reader has to guess which header belongs to
which column, and guesses wrong on merged or irregular tables.

## What stays your job

A caption is content:

```tcl
::pdf4tcllib::tag::begin $pdf Caption
$pdf text "Table 1: order items" -x 50 -y 200
::pdf4tcllib::tag::end $pdf
```

`tag::begin` and `tag::end` do nothing when tagging is off, so they can
stay in code that also produces plain PDFs.

## Checking

```tcl
puts [$pdf getUntaggedCount]     ;# 0
```

The script prints this at the end. Anything above zero is content that
belongs to neither an element nor an artifact -- wrap it, or mark it.

## Empty tables

An empty table is not tagged at all. Since pdf4tcl 0.9.4.43 a `Table` has
to hold a row and a `TR` has to hold a cell, so marking one up would be
refused at `tagEnd`; `simpleTable` therefore leaves it alone.
