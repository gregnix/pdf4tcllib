# How-to: a table over several pages

```bash
tclsh docs/en/howtos/howto-long-table.tcl
```

Companion: [`howto-long-table.tcl`](howto-long-table.tcl).

## The call

`table::render` breaks pages itself, so it needs the page geometry and two
variables it can update as it goes:

```tcl
set y      60
set pageNo 1
::pdf4tcllib::table::render $pdf $tableData 50 y 480 60 780 pageNo \
        595 842 25 10 14
```

`tableData` takes either form:

```tcl
# list form
{{Item Quantity Price} {left right right} {Part 1 3 1.75} ...}

# dict form
{header {Item Quantity Price} rows {{...} {...}} aligns {left right right}}
```

## What happens at the break

The header row is repeated on each new page -- and repeated as `TH` with
`/Scope Column`, not as ordinary cells. Measured on a 70-row table that
came to three pages:

| | |
|---|---|
| `Table` | 1 |
| `TR` | 73 -- 70 data rows plus one header row per page |
| `TH` | 9 -- three columns on three pages |
| `/Scope Column` | 9 |
| pages | 3 |

One logical table across three pages, which is what it is.

That the repeat is `TH` and not `TD` matters more than it looks. A reader
meeting a continuation page without headers has columns that mean nothing;
one meeting repeated `TD` cells is told the headers are data.

## Everything else follows the single-page rule

Grid lines and zebra stripes are Layout artifacts, cells are `TD`. See
[`howto-tagged-table.md`](howto-tagged-table.md).

## Checking

```tcl
puts [$pdf getUntaggedCount]     ;# 0
puts "pages: $pageNo"
```

`pageNo` is left holding the number of pages the table needed -- useful for
a footer, and a quick check that the break happened at all.
