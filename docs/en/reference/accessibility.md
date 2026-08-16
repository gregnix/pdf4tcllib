# Accessible documents with pdf4tcllib

What the building blocks mark up on their own, what stays your job, and how
to check. Applies to pdf4tcllib 0.6.1 with pdf4tcl 0.9.4.43.

Runnable companion: [`examples/basic/39_accessible.tcl`](../examples/basic/39_accessible.tcl).

---

## One line switches it on

```tcl
set pdf [::pdf4tcl::new %AUTO% -margin 25]
$pdf tagged 1
```

Without it nothing is marked up, and the same calling code produces a plain
PDF. pdf4tcllib asks once per document whether tagging is active and stays
quiet when it is not, so nothing needs to be written twice.

The probe it uses is `tagArtifact`, not a `tagBegin`/`tagEnd` pair -- the
pair looks harmless and is not: measured, it left an empty `Span` sitting in
the tree next to the table.

---

## What the building blocks do by themselves

| block | marks up |
|---|---|
| `table::render`, `table::draw`, `table::simpleTable` | `Table` / `TR` / `TH` / `TD`, header cells with `/Scope Column`; grid lines, zebra stripes and header background as Layout artifacts |
| `form::labelField`, `form::row` | `Form` element holding both the label and the field's `/OBJR` |
| `form::section` | `H2` for the title, Layout artifact for bar and frame |
| `form::separator` | Layout artifact |
| `page::header`, `page::footer`, `page::number` | Pagination artifacts |
| `page::grid`, `drawing::gradient_v`, `gradient_h` | Layout artifacts |
| `text::writeParagraph` | `P` by default, or whatever type you pass |
| `pdf4tcltable` (tablelist export) | delegates to `table::draw`, so covered |
| `labels::render` | one `Sect` per label -- each label is a unit of its own |
| `toc::heading` | `H1`..`H6` by level, plus a PDF bookmark |
| `toc::render` | `TOC` around the contents, `TOCI` per line, dot leaders as Layout artifacts |
| `chart::bar`, `line`, `pie` | one `Figure` with alternate text; grid, bars and axis labels as Layout artifacts |
| `flow::columns` | `P` by default, or whatever type you pass |
| `drawing::watermark` | Pagination artifact |

Two things worth knowing about that table.

**Decoration is marked as an artifact, not left alone.** Rules, shading and
grid lines carry no meaning; tagged as content a reader announces them as if
they did. That is worse than no markup at all -- it reads the separators out
loud between the numbers.

**Pagination is its own artifact type** (ISO 32000-1 clause 14.8.2.2).
Running heads and page numbers are not what the document says. Tagged as
content, the title is announced again on every page. A watermark belongs
here too: "DRAFT" says something about the copy in your hand, not about the
text, and hearing it in the middle of a sentence is worse than not hearing
it at all.

**A chart is a picture of numbers, and is marked up as one.** `chart::bar`
and its siblings produce a single `Figure` element with an alternate text
(`-alt`, falling back to the title) and mark everything inside it as an
artifact -- the grid, the bars, the axis labels. That is the honest answer:
a reader gets "Revenue per month, bar chart" rather than a scattering of
loose numbers in no particular order.

It is also a limit worth stating plainly. **If the numbers themselves
matter to a reader, put them in a table as well.** `getUntaggedCount`
reports 0 either way -- it counts what is unmarked, not what is
understandable, and a figure with a one-line description satisfies it
completely.

---

## What stays your job

Anything drawn with pdf4tcl directly belongs to nothing until you say
otherwise:

```tcl
::pdf4tcllib::tag::begin $pdf P
$pdf text "Drawn directly" -x 50 -y 700
::pdf4tcllib::tag::end $pdf

# decoration, no meaning of its own
::pdf4tcllib::tag::artifact $pdf -type Layout
$pdf line 50 710 450 710
::pdf4tcllib::tag::artifactEnd $pdf
```

Both helpers do nothing when tagging is off, so they can stay in code that
also produces plain PDFs.

`text::writeParagraph` takes the structure type as its last argument:

```tcl
writeParagraph $pdf $text 50 700 300                 ;# P
writeParagraph $pdf $text 50 90 400 14 left H1       ;# heading
writeParagraph $pdf $text 50 700 300 12 left ""      ;# nothing -- counted
```

The default is `P`, which is right for body text and wrong for a heading.
If you use this procedure to set headings, pass the type.

---

## Checking

**Before writing** -- how much content belongs to nothing:

```tcl
if {[$pdf getUntaggedCount] != 0} {
    puts stderr "[$pdf getUntaggedCount] painting operations belong to nothing"
}
```

Zero is what ISO 14289-1 clause 7.1 asks for. `finish` reports the same
thing once, in `::pdf4tcl::warnings`, and says so more sharply when the
document claims PDF/UA or an a-level.

Only painting operators count. Setting a colour or a font outside an element
is not a defect, and content inside an XObject is covered by the tag on the
`Do` that places it.

**After writing:**

```bash
qpdf --check out.pdf         # structure and streams; says nothing about conformance
verapdf -f ua1 out.pdf       # PDF/UA-1
verapdf -f 3a  out.pdf       # PDF/A-3a
```

Run both profiles on the same file. The interesting errors sit *between*
them: a PDF/UA conformant document can fail PDF/A outright and the other way
round.

---

## The font question

The 14 standard fonts have no embeddable font program, and both PDF/A and
PDF/UA require embedding (6.3.5 and 7.21.4.1). A document set in Helvetica
is tagged and still not conformant; pdf4tcl says so at `finish`:

```
PDF/UA: the standard font Helvetica has no embeddable font program ...
```

Load a TrueType font instead:

```tcl
pdf4tcl::loadBaseTrueTypeFont Base /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
pdf4tcl::createFontSpecCID Base Uni
$pdf setFont 11 Uni
```

Which of the three routes to take -- standard font, 256-character subset or
full CID font -- is compared with measured file sizes in pdf4tcl's
`0.9.4.x/doc/en/pdf4tcl-fonts-and-unicode.md`.

---

## What none of this answers

Whether a reader *understands* the table. A document can pass every rule --
`Table`, `TR`, `TH` with `/Scope Column`, no untagged content, embedded
fonts -- and still be read out in an order that makes no sense, or with
headers that name the wrong column.

veraPDF checks conformance, not sense. `getUntaggedCount` checks coverage,
not meaning. The remaining question needs a person with NVDA, JAWS or Orca.
