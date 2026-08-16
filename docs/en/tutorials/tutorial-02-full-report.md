# Tutorial 02 -- A complete report

What the modules look like when they work together: a contents page with
real page numbers, a two-column body, a chart, a table, and a watermark on
every page. Roughly eighty lines, and the only pdf4tcl calls in it are
`startPage`, `endPage` and `write`.

Run it:

```
tclsh tutorial-02-full-report.tcl [outdir]
```

Measured output:

```
Verzeichnis: 1 Seite(n)
Inhalt:      3 Seite(n)
ungetaggt:   0
  Ueberblick           2
  Umsatz               3
    Nach Monat           3
  Regionen             4
  Anhang               4
```

and, read back out of the file: the headings really are on pages 2, 3, 3, 4
and 4, the structure tree holds `TOC`, `TOCI`, `H1`, `H2`, `Figure`,
`Table`/`TR`/`TH`/`TD` and `P`, and there are six bookmarks.

---

## What a new page needs, in one place

```tcl
proc newPage {} {
    global pdf ctx pageNo
    if {[$pdf inPage]} { $pdf endPage }
    $pdf startPage
    incr pageNo
    ::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF"
    ::pdf4tcllib::page::header $pdf $ctx "Quartalsbericht 2026"
    ::pdf4tcllib::page::footer $pdf $ctx "vertraulich" $pageNo
    return [expr {[dict get $ctx top] + 34}]
}
```

Both the body and `flow::columns` call this. Writing it once is not
tidiness: a second copy would drift, and the page that got the drifted
version is the one nobody looks at.

**The watermark comes first.** pdf4tcl has no alpha channel, so the stamp
is drawn in plain grey and everything else lands on top of it. The other
way round it would hide the content.

---

## The body is a script, and it runs twice

```tcl
set content {
    set ::pageNo 0
    set y [newPage]
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Ueberblick"
    ...
}
set result [::pdf4tcllib::toc::document $pdf a4 $content -title "Inhalt"]
```

`toc::document` lays the document out twice -- once into a throwaway
document to learn which page each heading lands on, once for real with the
contents in front. So the script must not have side effects.

Note the first line of it: `set ::pageNo 0`. The page counter is **reset**
at the start rather than counted up across both runs. That is the shape
every piece of state in such a script has to take, and it is the one thing
that catches people out here.

---

## Handing the page break to the flow

```tcl
set res [::pdf4tcllib::flow::columns $pdf $ctx $body \
        -columns 2 -size 10 -top [expr {[dict get $ctx top] + 34}] \
        -firsty $y -newpage {set y [newPage]}]
set y [dict get $res y]
```

`-firsty` starts the first column below the heading that has just been
written; `-top` says where every *later* column starts. `-newpage` runs
whenever the last column is full, which is how every new page gets its
watermark and running head.

---

## A chart, and then the numbers

```tcl
set y [::pdf4tcllib::chart::bar $pdf $x $y $w 170 $umsatz \
        -title "Umsatz je Monat (kEUR)" -values 1 -format %.0f \
        -alt "Balkendiagramm: Umsatz je Monat, Januar bis Juni,\
              zwischen 98 und 178 tausend Euro"]

set y [::pdf4tcllib::table::draw $pdf $x [expr {$y + 16}] $cols $rows ...]
```

The chart is one `Figure` with an alternate text -- that is the honest
markup for a picture of numbers, and a reader gets the description rather
than a scattering of loose values.

**The table underneath is not decoration.** `getUntaggedCount` reports 0
with or without it: it counts what is unmarked, not what is
understandable. A figure with a one-line description satisfies it
completely, and a reader who needs the individual numbers still has
nothing. So when the numbers matter, print them as well -- as a table,
where they carry `TH`, `TD` and `/Scope Column`.

That is the whole difference between a document that passes the checks and
a document someone can use, and no tool in this library can tell the two
apart.

---

## What this does not do

* **No `-pdfa`.** The report is tagged and has a language; making it PDF/A
  conformant as well is one more option on `tagged` and a validator run
  that this sandbox cannot do.
* **No screen reader test.** Everything above was verified by reading the
  file. Whether the contents page reads as a list of chapters, and whether
  the chart description says something useful, needs a person with NVDA,
  JAWS or Orca.

---

## See also

* [`tutorial-01-accessible-report.md`](tutorial-01-accessible-report.md) --
  the same ground from the accessibility side
* [`../reference/pdf4tcltoc.md`](../reference/pdf4tcltoc.md),
  [`../reference/pdf4tclchart.md`](../reference/pdf4tclchart.md),
  [`../reference/pdf4tclflow.md`](../reference/pdf4tclflow.md)
* [`../reference/accessibility.md`](../reference/accessibility.md) -- what
  the markup buys and where it stops
