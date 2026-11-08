# How-to: a business document from a layout

```bash
tclsh docs/en/howtos/howto-template.tcl
```

Companion: [`howto-template.tcl`](howto-template.tcl).

## Two dicts

A delivery note has a sender line, an address, a few reference numbers, a
table of items and a closing remark. Where those go is the **layout**; what
they say is the **data**:

```tcl
set layout {
    paper a4  margin 20
    blocks {
        address {x 20 y 50 w 85 size 11 list 1}
        refs    {type pairs x 125 y 50 w 65 labelw 30 size 9}
        items   {type table x 20 y 108 w 170 cols {pos text qty unit}}
        note    {x 20 y 0 w 170 gap 8}
    }
}
set data {
    address {"Flower Shop Miller" "" "Main Street 5" "54321 Town"}
    refs    {Number LS-2026-0007 Date 2026-11-08}
    items   {{1 Rose 900 pcs} {2 Tulip 200 pcs}}
    note    "Thank you for your order."
}
::pdf4tcllib::template::render $pdf $layout $data
```

The layout stays the same for every delivery note and can live in a
settings table or a file; a designer such as `tkutils::tkulayoutcanvas`
edits it. The data is built per document.

## What follows the table

`note` has `y 0`: it is in the flow and starts 8 mm below the block before
it, the table. With 40 rows the table runs over two pages and the note
lands on the second, below the last row. Nothing in the program has to
know where the table ended.

## "Page n of m"

```tcl
foot {x 20 y 282 w 170 size 8 page all align center
      text "{name} -- page {page} of {pages}"}
```

`page all` repeats the block on every page. `{pages}` is known only after
the last page; `render` finds it with a dry run into a throw-away document
and then draws.

## What the module does not do

It computes nothing. The quantities, prices and totals are text when they
arrive. The program that issues the document computes them once, and the
PDF shows that result -- it cannot round differently.
