# Tutorial 1 -- an accessible report

```bash
tclsh docs/en/tutorials/tutorial-01-accessible-report.tcl
```

Companion: [`tutorial-01-accessible-report.tcl`](tutorial-01-accessible-report.tcl).

A report with a heading, body text, a table with a caption and a page
number -- built only from pdf4tcllib blocks, accessible from the first
line rather than repaired afterwards.

## Step 1 -- the font decides whether any of this counts

```tcl
::pdf4tcllib::fonts::init -fontdir [file dirname $ttf]
```

The 14 standard fonts have no embeddable font program, and both PDF/A and
PDF/UA require embedding. A report set in Helvetica is tagged and still not
conformant. Loading through `fonts::init` matters because the blocks take
their font from there.

## Step 2 -- tagging and language

```tcl
$pdf tagged 1 -ua 1 -lang en-GB
```

The language is not decoration: a reader picks its pronunciation from it,
and PDF/UA requires it, as does level A of PDF/A.

## Step 3 -- page furniture is not content

```tcl
::pdf4tcllib::page::header $pdf $ctx "Quarterly report"
::pdf4tcllib::page::number $pdf $ctx 1 1
```

Both become Pagination artifacts (ISO 32000-1 clause 14.8.2.2). Tagged as
content, the title would be announced again on every page.

## Step 4 -- headings carry their type

```tcl
writeParagraph $pdf "Sales by region" 50 80 400 15 left H1
writeParagraph $pdf "The figures below ..." 50 110 400 11
```

The last argument is the structure type; it defaults to `P`. The procedure
cannot tell a heading from body text, so a heading has to say so. A
document whose headings are all `P` passes every check and gives a reader
no way to navigate.

## Step 5 -- the table

```tcl
::pdf4tcllib::table::simpleTable $pdf 50 150 {140 90 90} $rows -zebra 1
```

First row `TH` with `/Scope Column`, the rest `TD`, decoration as
artifacts. See [`../howtos/howto-tagged-table.md`](../howtos/howto-tagged-table.md).

## Step 6 -- anything drawn by hand needs a decision

Content gets an element, decoration gets an artifact:

```tcl
::pdf4tcllib::tag::begin $pdf P
$pdf text "East grew fastest ..." -x 50 -y 290
::pdf4tcllib::tag::end $pdf

::pdf4tcllib::tag::artifact $pdf -type Layout
$pdf line 50 305 420 305
::pdf4tcllib::tag::artifactEnd $pdf
```

There is no third option. Content that is neither is counted and reported.

## Step 7 -- check, then write

```tcl
puts [$pdf getUntaggedCount]     ;# 0
```

Zero is what ISO 14289-1 clause 7.1 asks for. The script prints it and lists
any warnings.

## What this does not answer

Whether the report reads well. Every rule can be satisfied -- structure,
scopes, language, embedded fonts, no untagged content -- and the reading
order can still make no sense. That question needs a person with NVDA, JAWS
or Orca.
