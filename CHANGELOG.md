# pdf4tcllib Changelog

Notable changes per release. Pre-0.2 history reconstructed from git log
and module headers.

---

## pdf4tcllib 0.6.7, pdf4tclchart 0.1.2, pdf4tcltoc 0.1.1, pdf4tcltreeview 0.1.1 (2026-10-25)

Changed behaviour:

- `chart::bar`, `line`, `pie` (tagged): what is drawn inside the chart is
  now the content of its `Figure`, no longer a `Layout` artifact. Before,
  the `Figure` held nothing; pdf4tcl warned "the Figure element is empty
  -- no content, no child element and no annotation", and a reader had no
  area the alternate text belonged to. The alternate text is unchanged.
  Test `chart-tag-1b` now checks the content and the missing warning.
- `table::draw` understands `rowspan` (as `table::render` did): the cell
  holds its column in the following rows, is drawn over its whole height
  and tagged with `/RowSpan`; no page break inside such a block, a block
  taller than a page is an error. Before, the cell was drawn as an
  ordinary one and the next row shifted one column to the left. Tests
  `draw-rs-1.1` to `1.4`.
- `form::labelField`, `row`, `orderTable -cellForm`, `sumLine -id`: the
  configured `fieldBg` and `fieldBorder` (new: `fieldBorderW`, default 1)
  reach the field as `-bgcolor`, `-bordercolor`, `-borderwidth`, unless
  the call gives its own. Before, they reached no field, and a field had
  no frame. Forms look different now. Tests `fh-look-1`, `fh-look-2`.
- `table::draw` raises on an unknown option, like the other modules
  (`_checkOpts`). Before, `-zebar 1` for `-zebra 1` was stored and never
  read: no stripes, no message. Test `draw-opt-1.1`.

Fixes:

- `treeview::outline -bookmarks 1` wrote no bookmark at all: it called
  `bookmarkAdd` with the level as first word, pdf4tcl raised "unknown
  option", and `catch` swallowed it. Tests `tv-2.4`, `tv-2.5`.
- `toc::document -bookmarks 0` and `-gap n` had no effect on the
  headings, which read only `toc::configure`. They now apply for the call
  and the configuration is restored afterwards. Tests `toc-doc-8`, `9`.
- `table::draw`: the inner vertical lines ran through a merged cell
  (`colspan`), so a subtotal label from `table::group` read "Summe No|rd".
  The line on the left edge of a covered column is now left out. Test
  `draw-span-1.1`.
- `tests/test_subst_cid.tcl` held its test strings as UTF-8 text. Tcl
  8.6 reads a script in the system encoding, so under Windows (cp1252) or
  `LANG=C` seven tests failed with mangled input. The strings are now
  `\uXXXX` escapes, like in the other test files.
- `image::gallery`: the error for a frame too small for the grid ran the
  column count as a command (`[$o(-cols)]`), so instead of "the frame is
  too small for 2x3 cells" the caller got `invalid command name "2"`.
  Found while writing the error appendix of the book. Test `gallery-2.4`.

---

## pdf4tcllib 0.6.6 (2026-10-19)

`unicode::sanitize` in CID mode (`fonts::init -cid 1`):

- A code point the drawing face lacks becomes `?`, counted in
  `substReport`. Before, everything passed and pdf4tcl drew an empty
  `.notdef` box -- measured in a book build: a Japanese example line came
  out as a row of boxes.
- The face that draws is checked: `-mono 1` against the mono TTF, else the
  regular face. DejaVu Sans Mono lacks about 2700 glyphs of DejaVu Sans and
  has a few Sans lacks (U+238B).
- `-mono 1` keeps Unicode when the mono face is a TTF (`fontMono` =
  `Pdf4tclMono`). Before, it forced WinAnsi, and ⌘ → ∂ in code became `?`.
  With Courier as mono face it stays WinAnsi.
- Tabs become spaces, per line (`text::expandTabs`); new option
  `-tabwidth` (default 4). DejaVu has no tab glyph: a tab was drawn as a
  box, code indentation lost.
- New tests: `tests/test_subst_cid.tcl`.

---

## pdf4tcllib::table (2026-10-05)

- Cell text that is not a valid Tcl list (`{*}$args`, `{a}, b`, `"x": y`)
  no longer aborts a table with "list element in braces/quotes followed
  by ...". `_isCellSpec` treats such text as a plain cell.

---

## examples/_runner.tcl (2026-10-04)

- The time limit per example is kept in Tcl, no longer by `timeout(1)`. On
  Windows `timeout` found `timeout.exe` (a pause command), and
  `examples/run_all.tcl` failed every run with "Ungueltige Syntax".

---

## pdf4tcllabels 0.3

- New `render -frame layer`: label outlines in an optional content group
  "Label grid", switchable in the reader, not printed (`-print 0`). Drawn
  after the labels, closed before every `endPage`.
- `-frame layer` is an error where the grid would print anyway: pdf4tcl
  without `addLayer`, pdf4tcl up to 0.9.4.69, `-pdfa 2*`/`3*`. Check in
  `labels::LayerCheck`.
- Tests `labels-layer-1` to `-9`. Against pdf4tcl 0.9.4.69 the
  `-frame layer` tests fail by design.
- README: `-frame layer` needs pdf4tcl 0.9.4.70 or later.

---

## pdf4tcllib 0.6.5

### Added -- `table::draw -notruncate`

`table::draw` shortens every cell value to the column width and appends
`...`. That is right for remarks and model names -- a long name should
not break the column. It is wrong for values that have to be typed in
again: passwords, keys, checksums. The sheet looks correct and is not.

Shortening goes by **width, not by character count**. Measured
2026-09-14: 24 characters in capitals were cut, 29 mixed-case ones were
not. Anyone watching the length will miss it.

```tcl
set cols [list \
    [list -header "Field" -width 100] \
    [list -header "Value" -width 120 -notruncate 1]]
```

Per column as above, or per cell via `-cellstyles`. **The default stays
0** -- existing output is unchanged.

Four cases in `tests/test_table.tcl` (`tbl-notrunc-1.0` to `1.3`),
including one that fails if shortening ever starts counting characters
instead of measuring width -- the reason for the option would be gone
then.

### Added -- the test files report which package was loaded

`run_all.tcl` did; the individual files did not. A test run against the
**installed** copy instead of the tree looks exactly the same -- same
version number, different tree, no message. Measured three times on
2026-09-14/15, once while adding `-notruncate` itself: two cases failed
because the tree copy was never loaded.

---

## pdf4tcllib 0.6.4

### Added -- test_consistency.tcl, procedures that must agree

Five pairs answer the same question by different routes:

| | |
|---|---|
| `text::width` | `$pdf getStringWidth` |
| `measure::block` | the real drawing run |
| `table::fitRows` | where `table::draw` really breaks |
| `table::widths` | the width `draw` really needs |
| `text::wrap` | `drawTextBox` |

All five agree today. That is not self-evident, it is the state this file
holds: change one route and not the other, and it turns red here rather
than on paper.

The same shape as `consistency.test` in pdf4tcl, and for the same reason:
U+00AD was handled three different ways in one library on one day, each
correct on its own and each with passing tests. What nobody tested was
that they agree with each other.

**Counter-checked one pair at a time** -- `text::width` ignoring the pdf
object, `fitRows` miscounting the header, `measure::block` reporting 5 pt
short, `wrap` no longer breaking at a hyphen, `widths` reporting too
little. Each turns its own test red, `wrap` turns two.

Two of those counter-checks did **not** bite at first: the patch missed
the code and the run stayed green. A counter-check that does not bite is
itself unchecked -- it reports quiet where there is none. Which
intervention fells which test is therefore written into the file header.

### Fixed -- unicode::safeText left a hole in the structure tree

Measured: one call, `getUntaggedCount` 1. `safeText` is a public drawing
procedure and drew an untagged operation -- the same class as the form
labels, the text widget export and the arrows, all closed earlier in this
session.

**Found by a demo that checks itself** (`70_session.tcl`), not by the
suite.

It tags only when nothing else is open, because otherwise a `Span` would
nest inside a `P` as soon as a caller -- `table::draw`, `forms::` or
`math::_pdfBackend` -- had already tagged. `tag::depth` was added for
that question: how deep is this document currently in open elements. A
building block that draws by itself cannot otherwise know whether its
caller has tagged it, and has to choose between a hole and a nested
element.

### Added -- 70_session.tcl, a demo that checks its own claims

Seven pages on what this session changed, each stating the measurement
that found it. Every claim that can be checked is checked while the file
is produced; the run fails when one stops being true. It found the
`safeText` hole on its first run, in its own output.

### Added -- labels::render -clip, so nothing leaves the label

    pdf4tcllib::labels::render $pdf 3474 $records {x y w h rec} {
        $pdf text $rec -x [expr {$x + 4}] -y [expr {$y + 14}]
    } -clip 1

A name wider than the label ran onto the one beside it. Measured on the
rendered page, format 3474 (198.4 pt wide) with 60 characters at 11pt:
ink out to **363.6 pt** without, to **198.0 pt** with -- at the edge. On
screen this is invisible; on a sheet of labels it costs the batch.

`fitSize`, `wrap` and `ellipsize` are the better answer, because they
keep the text readable instead of cutting it mid-word. But they only help
whoever remembers them.

The path is opened with `gsave` and closed with `grestore` around each
label, so it applies to that one label. **The default is off**: a clip
nobody asked for would be a silent change of behaviour for every existing
call.

    pdf4tcllabels   0.1.1 -> 0.2

### Added -- tablelist::report, for what the export cannot carry over

    pdf4tcllib::tablelist::render $pdf .tbl 50 70 -maxwidth 480
    pdf4tcllib::tablelist::report
    # -> images 1 windows 1 wrapped 1 cells {0,0 1,0 1,2}

The point of this exporter is that what is on the screen goes into the
PDF. Three things it cannot do, and they used to disappear without a
word: a cell image, an embedded window, and a wrapped column --
`table::draw` does not wrap, so a cell the widget shows over three lines
becomes one, shortened with `...`. Measured with an 82-character text in
a wrapped column: the widget shows all of it, the PDF ends after 41
characters.

The report covers the **last** run rather than accumulating, or it would
sum over several tables and no one would know which is meant. A one-line
warning also goes to `::pdf4tcl::warnings`.

A wrapped column alone is not a loss -- a short value fits on one line
there too. Only a value longer than the column counts, estimated from the
character count, since the exact width is not known until `table::draw`
runs.

    pdf4tcltable   0.3.1 -> 0.3.2

### Fixed -- geometry-check now follows transformations, and found two defects

The check read path coordinates raw. Every canvas export therefore
reported findings, and all six in `examples/advanced` were written off as
false alarms because the drawing is placed with a `cm`. Six of those at
every run is worse than no check: one gets used to them.

It now keeps the current transformation matrix, following `q`, `Q` and
`cm`, and transforms each point before comparing. Four of the six really
were false alarms. The other two were defects nobody had looked at:

- **`55_canvas_items_matrix`** -- the table was 560 pt wide starting at
  x=42.5, so it ended at 602.5 on a 595 pt page. `pdftotext` saw nothing:
  the text stopped at 597.4, it was the rules that ran off.
- **`51_canvas_pdf_vs_ps`** -- page 2 stepped `y` the wrong way under
  `-orient true`, so the text ran off the top edge. Measured: the heading
  2 pt above the sheet, the embedded canvas 179 pt above it. Same shape
  as the sign error in demo 11 this morning.

**Reading tokens, not lines.** `demo_50` contains
`q 0.1 0 0 0.1 0 0 cm` -- two operators on one line. The line-based
parser missed both, dropped the 0.1 scale, and reported 93 findings that
were none. That one nearly went down as "canvas export, known false
alarm" as well.

`make geometry` now requires both directories to be clean; the `-` in
front of the advanced run is gone.

### Fixed -- missing characters were replaced in silence

    pdf4tcllib::unicode::resetSubst
    ... draw ...
    pdf4tcllib::unicode::substReport     ;# count 3 chars {U+03B1 U+03B2 U+2211}

`sanitize` replaces a character the font does not have with `?`. That
happened silently: neither the return value nor a counter said anything.
Measured on `math::renderLatex`, `\alpha \sum` without
`fonts::init -cid 1` produced six question marks in the content stream --
and the only sign was a stderr line nobody reads in a batch run.

This is the same shape as the other findings of this session -- an empty
page from a font name with a space, `-formatted` doing nothing, five
demos off the sheet: something goes wrong and nothing says so. It sits at
the point every piece of text passes through, which is why it went
first.

`substCount`, `substReport` and `resetSubst` work like `getSubstCount` in
pdf4tcl: cumulative, queryable, resettable. The report names up to twelve
distinct code points, because a number alone does not tell you which font
to load. A one-time warning goes to stderr as well.

**Not counted** are substitutions that are intended and lose nothing: the
emoji transliteration and the box-drawing characters in base mode.
Counted is where a character disappears. Latin-1 passes through, so
German text raises no false alarm.

`math::_pdfBackend` now draws through `safeText` rather than `$pdf text`.
A formula is mostly characters a standard font does not have; that was
the one place where the silence was guaranteed.

    pdf4tcllib     0.6.3 -> 0.6.4

### Fixed -- measure::fits said yes for a block that fitted nowhere

`measure::block` now reports `overflow` and `sheet`; `fits` reads the
first and answers no.

The page count rises only when a block breaks pages BY ITSELF. A block
that does not -- `text::writeParagraph`, for one -- runs off the bottom
instead, and `pages` stays 1. Measured: a paragraph repeated thirty
times on A4 gives height 1207 against a sheet of 841.89, seventy-one
lines of text, the last at y = -7.3, below the sheet. The measurement
and the real run agreed with each other, and both were wrong -- which is
why no consistency pair could find it, and why kon-7.1 to 7.3 stated it
as plain fact instead.

Neither checker sees it either: geometry-check does not look at text,
layout-check reads through pdftotext, and pdftotext drops what lies
beside the sheet (359 of 360 words).

kon-7.2 asserted the old answer and has been turned round; kon-7.4 is
the counter-check that a block which does fit still fits, and kon-7.5
reads overflow and sheet directly.

    pdf4tcllib     0.6.4 (unveroeffentlicht, keine Nummer dazu)

### Fixed -- pdf4tcltext: three points an application had to work around

A small app (pdfcompose) used the module through its public API, hit all
three and wrote them down. None of them was found by the test suite --
it checks what someone thought of beforehand, and all three sat in the
gap between an option that exists and an option that does something.

**`-maxwidth` did not break lines.** It was read into the option array,
handed to `_flushLine` as a parameter and never looked at: one line of
the widget became one line in the PDF, however long. Measured with
`-maxwidth 200` and a 200-character paragraph: ONE line, 987 pt wide, on
a sheet 595 pt across. The text left the page without a word said -- and
neither checker saw it, because `geometry-check` does not look at text
and `layout-check` reads through pdftotext, which drops what lies beside
the sheet. Now `_splitToLines` breaks at word boundaries, measuring each
segment in ITS OWN font, because a word in bold is wider than the same
word in regular. A single word wider than the space is still drawn:
cutting would be silent loss, and a loop would be worse than one wide
line. The drawing half of `_flushLine` moved into `_drawLine`.

**`pdf4tcltext::render` did not exist.** The alias at the end of the
file does `namespace import ::pdf4tcllib::textwidget::render`, but the
source namespace had no `namespace export`. Without an export pattern
Tcl imports nothing, and does so without an error -- the alias simply
did not come into being, while the reference documented it.

**A font loaded under the family name was ignored.** `_tclFontToPdf`
knew the 14 standard fonts only. A TrueType face registered as
`DejaVu Sans` came out as Helvetica -- the one font without glyphs
beyond Latin-1. `_loadedFontFor` now asks `pdf4tcl::getFonts` first,
from the most specific spelling to the least (`-BoldItalic`,
`-BoldOblique`, `-Bold`, `-Italic`, `-Oblique`, plain), and only then
falls through to the switch. The same reasoning as
`pdf4tcl::FindFontByFamily`. Unknown families still land on Helvetica,
and that fallback is tested on its own: without it, "recognised" and
"nothing found" would be indistinguishable.

**`-justify center` and `right` are applied.** They worked on screen and
vanished in the PDF, without a word said -- an application offered the
choice in its toolbar and had to label it "view only". The justification
of the first segment governs the whole line, as it does on screen: Tk
knows `-justify` per line, not per character. A line wider than the
available space is NOT shifted, because an alignment that carries the
text further out of the frame is no alignment (tw-just-2).

**`-offset` raises and lowers the baseline.** Superscript and subscript
were "not implemented": a footnote marker sat on the baseline like any
other character. The value shifts the baseline of that SEGMENT, not of
the line, and the line height is unchanged -- Tk holds it the same way.
No size is invented: a caller who wants smaller type gives the tag a
smaller -font as well, as on screen. tw-off-2 is the counter-check to
the counter-check: without the tag nothing may shift at all, otherwise
tw-off-1 would only prove that something is different.

Counter-check, each part separately: wrapping out -> tw-limit-1 and 1b
red; export out -> tw-limit-2 red; font lookup out -> tw-limit-3 red;
justify out -> tw-just-1 red; offset out -> tw-off-1 red.

    pdf4tcltext    0.2 -> 0.3

## pdf4tcllib 0.6.3

### Fixed -- form labels ignored the loaded font

`::pdf4tcllib::form` learned in `_family` that a caller who ran
`fonts::init` wants the loaded TrueType rather than the built-in
Helvetica. `::pdf4tcllib::forms`, the newer helper module, never got the
same treatment: no call to `_family` anywhere, and seventeen direct reads
of `CFG(fontFamily)`, which holds `Helvetica`.

Every field label and every checkbox label was therefore drawn in the one
font that has no embeddable program. Measured with a text field and a
checkbox at `-pdfa 2b`: one warning from pdf4tcl naming a font the caller
never asked for, and veraPDF **FAIL 2b**. With the fix: no warning,
**PASS 2b**. An explicit `form::configure -fontFamily` still wins -- only
the default follows `fonts::init`, exactly as in `form::_family`.

This is what closed the gap the TODO list called "der offene Nachweis":
no example combined a checkbox with `-pdfa`, and it turned out none could.

### Fixed -- field captions sat outside the structure tree

`_tagBeginField` wraps the field itself in a `Form` element, with `-alt`
from the label. The *visible* caption beside it was not wrapped. Measured
with `getUntaggedCount` on a tagged document: one text field 1, one
checkbox 1, both together 2 -- one hole per caption, which a reader skips
and PDF/UA fails over. Now wrapped in `Lbl` (ISO 32000-1 table 335), in
`_labelWithRequired` and in `checkboxLine`. Does nothing when tagging is
off.

    pdf4tclforms   0.2.1 -> 0.2.2

### Added -- merged cells across columns

A table cell may be given as a dict instead of a string:

    [dict create text "Summe" colspan 3]

The widths of the covered columns are added up, the following columns
fall away in that row, and the cell carries `/ColSpan 3` (ISO 32000-1
table 349, clause 14.8.5.7). The attribute is not decoration: clause
14.8.4.3.4 note 2 says the association between a header and its data
cells is determined heuristically and "may fail for complex tables". A
merged cell is exactly such a case, and without the attribute a reader
announces the wrong heading.

Recognised by the combination of a `text` and a `colspan` key, so a
plain cell would have to read literally "text ... colspan ..." to be
mistaken for one. An unusable span -- zero, negative, not a number --
counts as one rather than raising.

Three places had to learn about it beyond the drawing itself: the column
count (a header `{Region {text Zahlen colspan 2}}` describes three
columns, not two -- taking the number of entries lost the third column
and its data), the width calculation (a merged cell must not pull a
single column to its width) and the row height (a merged cell has more
room, so it wraps later).

### Added -- merged cells across rows

`rowspan` works the same way, and as in HTML the covered cells are simply
left out of the following rows:

    {text "Nord" rowspan 2} Q1 120
                            Q2  90

Three things had to come with it. An **occupancy plan**, because the row
alone no longer says which column a cell sits in -- `Q2` above is the
first entry of its row and belongs in the *second* column. **Row heights
computed in advance for the whole table**, because a cell spanning three
rows needs as much room as those three give it, and when they do not give
enough, the last of them has to grow -- otherwise the text sits on top of
the separator. And the **separators themselves**, which are now drawn in
segments: where a cell continues downwards, the line leaves a gap, or the
merge would exist in the tree but not on the paper.

The cell carries `/RowSpan` (ISO 32000-1 table 349), and the two combine:
a cell may span rows and columns at once.

**Limitation, measured:** a merged block that meets a page break is not
repeated on the next page. Nothing is lost and the tree stays complete --
the text is drawn once, in the row where the cell starts, and the rows on
the following page keep their own cells. Splitting or repeating a merged
cell across pages is a separate step.

    pdf4tcllib     0.6.2 -> 0.6.3

### Added -- layout::stack, blocks one under another

    ::pdf4tcllib::layout::stack $pdf $x $y $w {
        {script {::pdf4tcllib::text::writeParagraph $bpdf $intro $bx $by $bw}}
        {gap 12}
        {script {::pdf4tcllib::table::draw $bpdf $bx $by $cols $rows
                        -maxwidth $bw} keep 1}
    } -ctx $ctx -font {10 Helvetica}

What a caller writes by hand today: draw a block, take the returned y,
add a gap, draw the next -- and watch the page break yourself. That loop
is in every report, and it is a little differently wrong every time.

It uses what came before it: `measure`, to know **before** drawing
whether a block still fits on the page, and `state`, so one block does
not leave the next with the wrong font.

**One shape for all of them.** `table::draw` returns a y, `image::place`
an area, `callout` a line count; `stack` returns `{x y w h}` for each.

`keep 1` measures the block first and starts a new page if it would not
fit whole -- rather than letting it split. Without it nothing is measured
and nothing is broken: the block handles it itself, as before.

In each script `$bpdf`, `$bx`, `$by` and `$bw` are available. **`$bpdf`
rather than `$pdf`** on purpose: while measuring it is the throwaway
document, and a script naming `$pdf` would draw into the real one during
the measurement. The script runs in the caller's scope, so its own
variables are visible; the four names are restored afterwards.

`measure::block` would have been the obvious way to measure here, but it
evaluates its script one level up -- two nested `uplevel`s and the count
no longer works out. The throwaway document is therefore created in
`stack` itself, and the block runs at the same level as when drawn.

### Changed -- table::draw reads the page direction, and refuses the one it cannot serve

`text::writeParagraph` has always asked the document itself
(`$pdf cget -orient`). `table::draw` wanted the direction as an option
with default 1, so on a document created with `-orient 0` the page break
ran the wrong way and nobody said anything. It now reads the document
when the caller does not say; an explicit `-orient` still wins.

**And `-orient 0` is now refused rather than half served.** The option
steers only the page break, not the direction the rows run in: under
`-orient 0` the table grows *upwards* and the header ends up at the
bottom -- measured on a three-liner at y=100, header at PDF-y 112 with
the rows above it at 128 and 144.

Straightening that out inside `draw` would be about ten places computing
`y + rowH`. But it would fix only half the chain: `page::context`
delivers `top` and `bottom` measured **from the top of the page**, and
the page break here, `page::header`, `page::footer`, `flow::columns` and
`toc` all read them. The rows would run the right way and the break would
test against a boundary meaning the opposite -- half fixed is worse than
not fixed.

A library that knows it is drawing wrongly should not do it anyway. The
error names the way out (`-orient 1` on the document, or explicitly on
the call). Whoever really needs the other direction will now say so, and
then it is also known what else they use.

### Added -- table::widths, the natural and the smallest width

    set w [::pdf4tcllib::table::widths $cols $rows -pdf $pdf]
    dict get $w natural   ;# per column, nothing wraps
    dict get $w min       ;# per column, the longest word still fits

A layout engine distributing columns asks two things: how wide does this
want to be if allowed, and how narrow can it still go. Between the two it
can distribute; below `min` something is cut or breaks mid-word.

`min` is the **longest word** per column, not the widest character. A
word that does not fit is cut character-wise, and that is not a lower
bound but an emergency.

Both are computed with the same measurement `table::draw` uses, so with
`-pdf` when it is given -- without it `text::width` estimates from
character classes, which is far off for a CID font. A cell merged across
columns does not inflate any single column, as in `_calcColWidths`.

### Added -- table::breakPoints and table::fitRows

    set n [::pdf4tcllib::table::fitRows $space $rows -groups $groups]

A layout engine does not say "break if you must", it asks "may I split
here, and where". `table::draw` breaks by itself, but by its own rules
and without saying anything beforehand.

`breakPoints` returns the row height, the header height, the cumulative
heights and the row numbers **before which no break is allowed**;
`fitRows` answers how many rows go on a page of a given height, stepping
back to the last allowed point.

Two things forbid a break:

- **Inside a cell merged across rows.** Such a cell is not repeated on
  the following page, so a break would tear it apart visually. Measured:
  with a `rowspan 3` at the top, 60 points of space take **no** rows at
  all rather than two -- the whole block moves to the next page.
- **Directly after a group heading.** A heading with no content at the
  foot of a page is not a heading. `table::group` returns those row
  numbers in `groups`; pass them in and they are honoured.

The row height in `table::draw` is uniform and its cells do not wrap, so
this is arithmetic rather than measurement. It does not hold for
`table::render`, which does wrap.

### Added -- pdf4tcllib::measure, asking how tall a block will be

    set m [::pdf4tcllib::measure::block mp {
        ::pdf4tcllib::table::draw $mp 0 0 $cols $rows -maxwidth 400 -ctx $ctx
    } -paper a4]
    dict get $m height    ;# how much height it needs
    dict get $m pages     ;# how many pages it runs over

A layout engine has to ask how tall a block will be *before* it knows
which page it goes on. No building block answers that: they all draw and
return a y afterwards.

The cheap route would be a `-dryrun` in every drawing procedure. That
means two cases in each of them, and the measuring case would be used
less often than the drawing case -- so it would be the one to go wrong
first. Here the block is really drawn, into a throwaway document that is
never written. What is measured is by construction the same thing that
comes out later; `me-1.2` checks that the two agree to a thousandth.

Fonts are shared across documents (pdf4tcl keeps them in the namespace,
not per document), so the throwaway document knows the same CID fonts --
measured.

**The page count is a property of the call, not of the block.** Without
`-ctx`, `table::draw` does not break and draws past the page edge, and
the measurement says one page. Measure the way you will draw. `me-1.5`
holds that down so nobody reads it as a promise.

A block that returns something other than a number gets an empty height
rather than an invented one.

### Added -- pdf4tcllib::state, keeping the drawing state across a block

    ::pdf4tcllib::state::with $pdf {20 Helvetica-Bold} {1 0 0} {
        ::pdf4tcllib::table::draw $pdf ...
    }

A building block leaves font and colour as it last needed them, not as it
found them. Measured around `table::draw`:

    before   /Pdf4tclSansBold 20 Tf,  1 0 0 rg
    after    /Pdf4tclSans 9 Tf,       0 0 0 rg

Drawing by hand, nobody notices. Putting blocks one after another -- which
is all a layout engine does -- gives results that depend on the order.

**Why not `gsave`/`grestore`.** The PDF pair `q`/`Q` does save the state
including font and colour, and inside one page it is the right tool. But
it applies per content stream, and every page has its own: a `q` on page 1
with its `Q` on page 2 leaves two unbalanced streams. Measured -- and
neither pdf4tcl nor qpdf says anything, because each stream on its own
remains readable. That happens with every block that breaks pages by
itself: `table::draw`, `flow::columns`, `toc::document`.

So the state is kept on the Tcl side and restored with `setFont` and
`setFillColor`, which survives a page break. The values come from the
caller, because pdf4tcl has no getter for the current font or colour --
`getFontMetric` exists, `getFont` does not. What was not saved is not
touched: a default would be a claim rather than a restoration.

`with` restores even when the block raises, and passes the block's result
through.

### Added -- pdf4tclcanvas, a canvas exporter

    package require pdf4tclcanvas
    ::pdf4tcllib::canvas::place   $pdf $c $x $y $w $h ?-option value ...?
    ::pdf4tcllib::canvas::fitPage $pdf $c $ctx ?-option value ...?

The drawing is not done here -- `$pdf canvas` has done it for a long
time, for `tk::canvas`, `tkpath` and `tko::path`. Like `pdf4tcltable` and
`pdf4tcltreeview` this is an adapter, and it takes over the two things
around it:

**The scale.** `$pdf canvas` takes `-width` and `-height` and pulls the
drawing onto them. Where the aspect ratio of the frame differs from that
of the drawing, it is distorted -- exactly as `putImage` does with an
image, and just as silently. `place` computes the scale from the bounding
box and keeps the ratio; `-fit stretch` restores the old behaviour, and
`-anchor` says where the drawing sits in the frame.

**The structure tree.** A canvas export leaves holes: measured on four
items -- rectangle, oval, line, text -- three open drawing operations.
With `-alt` the drawing becomes a `Figure`, without it an artifact. A
drawing without a description is worth nothing to a reader, but a hole in
the tree is worse than decoration.

`-caption` writes a caption inside the `Figure` as a `Caption`, set
smaller rather than cut, as in `image::gallery`. An empty canvas has no
bounding box, which used to abort `$pdf canvas`; the widget size is used
instead.

    pdf4tclcanvas 0.1   (new)

### Fixed -- the text widget export left the structure tree empty

`pdf4tcltext` resolves the markup of a text widget -- font, colour,
underline, overstrike -- including overlapping tags, which Tk allows and
a structure tree does not like. What it did not do was tag anything:
every run of text, every coloured box and every rule sat outside the
tree. Measured on a widget with four tags: **8 open drawing
operations**.

A line is now a `P` and the runs inside it are `Span` -- they differ in
markup, not in role. Backgrounds, underlines and overstrikes are
artifacts: they carry no text a reader could announce.

Note that a word split by a tag boundary is written as two `Tj`
operations, which is correct -- the extracted text reassembles it.

    pdf4tcltext   0.1 -> 0.2

### Added -- forms::read and forms::write, the round trip

    set data [::pdf4tcllib::forms::read filled.pdf -schema $schema]
    dict set data f_ok 1
    ::pdf4tcllib::forms::write filled.pdf out.pdf $data

`forms` built fields from a schema; the way back -- a filled PDF into a
data set -- was missing. pdf4tcl has delivered the raw material since
0.9.4.55, but in PDF terms:

    f_ok -> type /Btn default /Yes value /Yes flags 0

What the caller wants is `1`. And when writing, the caller wants to write
`1`, not `/Yes`: the state names of a checkbox live in the `/AP`
dictionary and are a matter of the format, not of the application.

`read` returns id → value, with `/Btn` as 1 or 0 and `/Tx` as the string;
`-raw 1` gives what `getForms` said. "Off" is tested against `/Off`
rather than `/Yes`, because a foreign form may name its on-state
differently.

With `-schema` -- the same field definitions the form was built from --
two more things come out: the order of the schema instead of the order in
the PDF, and a report of which fields are missing or extra. Without a
schema neither would be noticed. `-strict 1` raises instead of warning,
on both procedures.

    pdf4tclforms   0.2.2 -> 0.2.3

### Added -- watermark as an optional content layer

    lassign [drawing::watermark $pdf $ctx "ENTWURF" -layer 1] size layer
    # on the following pages:
    drawing::watermark $pdf $ctx "ENTWURF" -layer $layer

`watermark` drew onto the page, and that is a nuisance for a draft mark:
somebody who wants to read or print the text without "ENTWURF" across it
cannot. As a layer it can be switched off in the reader.

`-layer 1` creates one named after the text and returns its id together
with the size; passing that id on the following pages puts them all in
**one** layer rather than one per page, which is what the reader's layer
list would otherwise look like.

Without `-layer` nothing changes: an artifact, drawn onto the page. The
watermark stays an artifact either way -- a layer does not make it
content.

### Added -- table::pivot, a cross table

    set p [::pdf4tcllib::table::pivot $rows -row 0 -col 1 -value 2]
    ::pdf4tcllib::table::draw $pdf $x $y $cols [dict get $p rows]

Turns rows of `{region quarter amount}` into a table with the regions as
rows and the quarters as columns. Three decisions come with that, and the
arithmetic makes none of them:

- **Which columns exist.** They follow from the data, not from an
  argument -- a quarter that appears in no row does not appear in the
  table. `-colorder` fixes the order, otherwise they are sorted.
- **What an empty cell says.** A cross table almost always has gaps, and
  `0` is not the same statement as "nothing measured". The default is the
  empty string; `-empty` sets something else.
- **What happens when a field has several values.** The default is to
  add them; `count`, `avg`, `min` and `max` are there too.

A value that is not a number is skipped by `sum`, `avg`, `min` and `max`
-- counting it as zero would invent a measurement. `count` counts it,
because it counts rows rather than values.

Returns a dict: `header`, `rows`, `cols` and `total`.

### Added -- table::group, grouping with subtotals

    set g [::pdf4tcllib::table::group $rows -by 0 -sum 2]
    ::pdf4tcllib::table::draw $pdf $x $y $cols [dict get $g rows] \
            -rowstyles $styles

Groups a list by a column, puts a subtotal after each group and a grand
total at the end. The arithmetic is trivial; what takes work is around
it, and that is what the procedure does:

- **The rows have to be sorted.** They are not sorted here -- an order
  the caller chose deliberately is not ours to rearrange -- but an
  unsorted list is reported, because otherwise a group falls into several
  blocks and each gets its own subtotal. `-strict 1` raises instead.
- **The subtotal label spans the text columns**, as a merged cell.
  Otherwise "Summe Nord" would sit in the region column with the quarter
  empty beside it, and the row would look like data.
- **The caller has to know which rows are totals** to set them in bold.
  So `group` returns a dict: `rows`, `subtotals`, `groups`, `total` --
  the last three being row numbers for `-rowstyles`.

A value that is not a number is skipped rather than counted as zero: an
empty field is not a zero, and "k.A." even less so.

`-header 1` puts a heading row before each group, `-blank 1` leaves the
group value only in the first row of its group.

### Fixed -- table::draw ignored merged cells

`colspan` arrived in `table::render` with 0.6.3, but `draw` has its own
drawing path, and there the dict form was written into the PDF verbatim:
`text {Summe Nord} colspan 2`. So `table::group` would have worked with
`render` only. `draw` now reads the same cell specs, sums the widths and
writes `/ColSpan`.

### Changed -- the two math demos are demos again

`math_formula_demo.tcl` and `math_inline_demo.tcl` did not start with a
digit, and the batch runner collects `[0-9]*.tcl`. So they were never run
by `run_advanced.tcl`, never checked, and never in `pdf/` where the
conformance and geometry checks look. They are now `68_math_formula.tcl`
and `69_math_inline.tcl`, and they write to `pdf/` like every other demo.
Both run: 329 and 316 ms, nothing outside the page.

### Documentation -- the LaTeX subset had none

`API.md` described the eqn-style notation and `renderFormula`. The second
entry point -- `renderLatex`, `measureLatex`, and the backend forms
`renderLatexOn` / `measureLatexOn` with `pdfBackend` and `canvasBackend`
-- was in the code and in no page at all, although it handles
superscripts, subscripts, `\frac`, `\sqrt`, `\sum` with limits and the
Greek letters.

Documented with measured numbers rather than claims: `measureLatex`
returns `{width above below}`, and the table in the page lists what five
formulas actually measure at size 12.

With a note that costs an hour when it is missing: without
`fonts::init -cid 1` the Greek letters and operators come out as question
marks. Measured -- `\alpha \sum` produced six of them, and nothing said
so.

### Documentation -- read, not only run

The how-tos and tutorials were checked against their scripts line by
line, rather than only run.

They hold up: what `howto-images.md` says about `Figure`, alt text and
artifacts is what its script does, and the numbers in `howto-charts.md`
(35 loose drawing operations before the `tagged 1` call moved to the top,
0 after) are still the numbers the script reports.

Two gaps, both from the library having grown past them:

- `howto-long-table.md` ended at "render breaks where it must". It now
  points at `fitRows` and `breakPoints` for deciding beforehand, and at
  `layout::stack`.
- `API.md` documented `pivot` and `group` but not `breakPoints`,
  `fitRows` or `widths`. All three are in now.

German left in the documentation: the messages of two scripts, the sample
data of `howto-charts` (`Mrz`, `Nord`, `Sued`) and most of
`tutorial-02-full-report`, whose report was German throughout -- headings,
chart titles, alt texts, the printed summary. Translated, script and
prose together, and re-run so the output in the text is the output the
script produces.

### Documentation -- the five namespaces that had none

`API.md` never mentioned `tag`, and since last night not `state`,
`measure` or `layout` either. All four are in now, with what they are
for rather than only what they take -- `tag` in particular, because it is
used by every module and was documented nowhere but in passing.

`pdf4tclcanvas.md` is new: the last module without a reference page.

Version statements that had aged: `docs/en/README.md` and
`accessibility.md` said "pdf4tcllib 0.6.1 with pdf4tcl 0.9.4.43",
`table-draw.md` said `pdf4tcltable 0.3`.

`pdf4tclchart.md` records that the pie used to be drawn twice its
intended size and off to the left, so charts produced with 0.1 look
different from charts produced now.

`flow::configure` was in the code and in no page.

Checked and found right, contrary to what a first pass suggested:
`pdf4tcllabels` (its procedures live inside a `namespace eval`, which my
grep missed), `toc::pageCount` and `chart::niceScale`.

### Changed -- the demos speak English

The demos were part German, part English. Translated so far, across all
37 files that had German in them: the repeating header block (the Windows
note, the octal pitfall, "Lernziele"), and the messages they print --
"Geschrieben:", "Mit Debug-Grid:" and their kin.

**The text that goes INTO the PDFs** is translated demo by demo, each one
run and checked afterwards rather than in one sweep, because English
strings are a different width. **The demos are done.** In `examples/basic` all but three, in
`examples/advanced` all but the sample data noted below. Every other demo
carries exactly one German line: the comment `# Encoding test: äöüÄÖÜß€`,
which describes what the file exercises.

In `examples/advanced` the German that is left is **sample data that
exercises the encoding**: German company names and towns going through
tablelist, `-formatcommand` and the PDF in `56_tablelist_pdf`, and
through a CSV file in `42_batch`. Both now say so at the point where the
data is defined -- with "Main Street" and "Springfield" that chain would
no longer be tested.

The three left in German are the ones where the language is arguably the
subject: `20_invoice`, `18_address_labels` and `19_business_card` -- a
DIN 5008 business letter, address labels and a business card, all with
German addresses. The first says so at the top; the other two are left
for the author to decide.

**`20_invoice` stays in German, and says so at the top.** It lays out a
business letter to DIN 5008: sender line above the address field, the
window position, folding marks, 19% VAT, IBAN and BIC, the commercial
register entry. Those are German conventions and the language is part of
them; a letter that follows the standard but is written in English would
be neither one thing nor the other. Same reasoning as the encoding
tests, whose umlauts also stay. Umlauts stay
where they are the point of the line -- `05_lists` and `07_simple_table`
carry encoding tests, and those keep their characters, written as `\u`
escapes so the file itself is plain ASCII.

The rest is still German inside the PDF. That is deliberate. English strings are a different width, and
we have just spent a session finding drawings that ran off the page --
translating visible text without re-running the geometry and layout
checks would put some of it back. So that part goes demo by demo, each
one run and checked afterwards, rather than as one sweep.

One nuance worth keeping in mind: several demos carry umlauts **as an
encoding test**. `Umlauts: äöüÄÖÜß` in demo 01 stays in the PDF -- it is
the point of the line, not an oversight.

### Fixed -- chart::pie drew outside its frame

`pdf4tcl::arc` takes `x0 y0 rx ry phi extend` -- a **centre and two
radii**. `chart::pie` passed `[cx-r] [cy-r] [2r] [2r]`, a bounding box:
the centre landed r up and to the left, and the circle came out twice the
intended size. Measured with a frame at x=60..540: the path started at
x=44 without a legend and at **x=-47 with one**, 107 points off the
sheet. That is the pie hanging over the left edge in `demo_41_charts`.

    pdf4tclchart   0.1 -> 0.1.1

### Added -- tools/geometry-check.tcl, and five demos that ran off the page

`layout-check.tcl` reads the text with pdftotext, so it sees nothing that
is **drawn**. Five demos in `examples/basic` therefore ran past the edge
without any check noticing:

| demo | what was wrong |
|---|---|
| `27_patterns` | third pattern at x=520, 200 wide, on a 595 wide page |
| `18_address_labels` | 3 columns of 70 mm labels = 609 pt; 8 rows = 873 pt |
| `19_business_card` | 5 rows of 55 mm cards, last row below the sheet |
| `04_lines_boxes` | closing box drawn at the running y, past the bottom |
| `11_coordinate_system` | the orient-false branch computed against the page height instead of the origin, so the three sample points landed at PDF-y -442, -342, -242 |

The counts are now computed from `SW` and `SH` rather than written down,
and the closing box moves up when it no longer fits.

`geometry-check.tcl` uncompresses with qpdf, walks the content streams
and reports `re`, `m` and `l` outside the MediaBox. `make geometry` runs
it. It does **not** see `cm` transformations, which is why the six
remaining hits in `examples/advanced` are canvas exports and false
alarms -- that target reports but does not fail. Curves are skipped
rather than reporting control points that legitimately sit outside.

### Documentation -- the numbers and the refused direction

README said "424 tests in 20 files", measured are 527 in 27.
`table-draw.md` still listed `-orient 0|1` as a working option "for the
internal page break" -- it now says the option is read from the document,
that only `1` is served, and quotes the error with the way out. `API.md`
gained a short section naming which building blocks handle orient 0 at
all: `page::_advance`, `form::*` and `text::writeParagraph` do,
`table::draw` does not.

### Added -- documentation for what was built

`docs/en/reference/pdf4tcltreeview.md` is new. `API.md` gained the parts
that had none: `text::wrap` and its separators, `text::fitSize`,
`drawing::arrow` and `callout`, `image::place` and `gallery`, and merged
cells under `table::render`. `pdf4tcltable.md` records why `-formatted`
used to do nothing.

### Fixed -- two version numbers that had drifted apart

`package provide` said 0.6.3, `pdf4tcllib::version` returned **0.3**, and
`API.md` documented 0.2. The second number was maintained beside the
first and forgotten at every bump, so it is now derived from it:

    variable version [package provide pdf4tcllib]

The file header still described `pdf4tcllib-0.1.tm`, "2544 lines" and
`package require pdf4tcllib 0.1`; it now lists the eleven namespaces that
are actually there and the packages built on top. README said "348 tests
in 16 files" -- measured are 424 in 20 -- and named `pdf4tcllib-0.6.1.tm`
in the prose while the table said 0.6.3.

63 examples, tests and documents asked for `pdf4tcllib 0.1` or `0.2`.
They all use features from 0.6, so they now ask for 0.6; the old pin was
satisfied by any version and said nothing.

### Added -- drawing::arrow, arrowHead and callout

    ::pdf4tcllib::drawing::arrow    $pdf $x1 $y1 $x2 $y2 ?-option ...?
    ::pdf4tcllib::drawing::callout  $pdf $x $y $w $h $tx $ty $text ?...?

A connection in a diagram is a line plus a triangle, and the triangle is
the work: it has to point along the line, and the line has to stop
**before** it, or it draws through the filled area and leaves a seam down
the middle. `-at` puts heads at the end, the start or both; `arrowHead`
alone sets a head at the end of a path the caller drew.

`callout` is a rounded box with a pointer at the side facing the target
-- which side follows from the geometry and is not an option. Text too
tall for the box is set **smaller, not cut**: a speech bubble usually
holds one sentence, and half a sentence is none.

Both are wrapped as artifacts where they are decoration. Without that,
every line and every triangle counts as untagged: measured on three
arrows and two callouts, nine open drawing operations, so a diagram would
have as many holes in its structure tree as it has connections. The text
inside a callout is content and stays in the tree.

### Added -- image::place and image::gallery

    ::pdf4tcllib::image::place   $pdf $id $x $y $w $h ?-option value ...?
    ::pdf4tcllib::image::gallery $pdf $images $x $y $w $h ?-option ...?

`putImage` takes `-width` and `-height` and stretches the picture onto
them. Where the aspect ratio differs the picture is distorted, and
nothing says so. `place` makes the decision instead:

    -fit contain   fits inside, margin stays free  (nothing is lost)
    -fit cover     fills the frame, overhang is cut (nothing stays empty)
    -fit stretch   the old behaviour

And when it cuts, `-anchor` says from where -- a portrait with the head
at the top wants `n`, a landscape usually `center`. Cutting is done with
a clip path, so the picture is drawn at its computed size and only the
frame shows. What lies outside is still in the file; crop beforehand if
that matters.

`-dpi` warns per image below a threshold, and switches off the core's own
warning for that call, because two messages about one picture are one too
many. `-alt` wraps the image in a `Figure`.

`gallery` puts images into a grid across pages, with captions. A caption
is written **inside** the image's `Figure` as a `Caption`, so the two
belong together in the tree rather than standing next to each other
unconnected. A caption too wide for its cell is set smaller rather than
cut -- with a file name or a picture number it is often the last
character that matters -- which is what `text::fitSize` above is for.

### Fixed -- -formatted had no effect

`pdf4tcltable::_extract` read the rows with `getformatted` and then
overwrote every cell with `cellcget -text`, which returns the **raw**
value. So `-formatted` did nothing, for as long as the option has
existed. Measured on a column with a `-formatcommand`: the PDF showed
`1` where the widget showed `ja`, with `-formatted 1` exactly as with 0.

The access is still needed without formatting -- there it picks up text a
caller set through `cellconfigure -text` -- so it now runs only in that
case.

    pdf4tcltable   0.3 -> 0.3.1

### Changed -- demo 58 builds its own table

It loaded `miscWidgets_tile.tcl` from the tablelist collection, which
needs two packages Tk does not ship: Bryan Oakley's `combobox` and
`mentry`. Where those are missing the demo aborted -- in the batch run
with "can't find package combobox" -- so it was never checked.

It does not need them: tablelist takes `ttk::combobox`, `ttk::spinbox`
and `ttk::checkbutton` as edit windows on its own. The demo now builds
its table itself and runs with Tk and tablelist alone. It also shows what
`-formatted` is for, now that the option works.

### Added -- pdf4tcltreeview, a ttk::treeview exporter

    package require pdf4tcltreeview
    ::pdf4tcllib::treeview::render  $pdf $tv $x $y ?-option value ...?
    ::pdf4tcllib::treeview::outline $pdf $tv $x $y ?-option value ...?

A `ttk::treeview` is two things at once: a table with columns and a tree.
`render` draws the table -- the shape you recognise from the screen --
with the tree column indented; `outline` draws the tree column alone as
an indented list with a bookmark per node, which makes it navigable in a
reader.

The tagging differs between the two, and that is the reason for two
procedures rather than an option: a table is `Table`/`TR`/`TD`, an
outline is `L`/`LI`/`LBody`. Which one applies cannot be guessed from
the widget -- a treeview with three value columns is a table, one with
only the tree column is a list.

Like `pdf4tcltable` this is a **thin adapter**: it reads the widget and
hands over to `::pdf4tcllib::table::draw`, which has done indentation
since 0.3 via `-rowindent`. No second renderer.

A closed branch stays closed: the PDF shows what was on the screen.
`-all 1` takes everything. Column widths come from the widget in pixels
and are scaled to `-maxwidth`, the alignment from `-anchor`.

    pdf4tcltreeview 0.1   (new)

### Changed -- one line-breaking rule, not two

`text::wrap` broke at spaces only, and cut an over-wide word
character-wise: "Muster-Beispiel-Stadt" in a 60 point column came out as
"Muster-Beispi" / "el-Stadt", with nothing to show the word continues.
pdf4tcl breaks at the hyphen in `drawTextBox` since 0.9.4.60, so the same
string came out differently depending on which of the two drew it.

`wrap` now breaks inside a word at a hyphen or slash **between two
characters**, keeping the separator at the end of the line, and it uses
the same rule as the core: a hyphen after anything but a letter or digit
does not break, so "-5 Euro" stays together. The separators are the last
argument; pass `{}` for the old behaviour.

    "Muster-Beispiel-Stadt"    ->  "Muster-" / "Beispiel-Stadt"
    "Der Betrag -5 Euro"       ->  "Der Betrag -5" / "Euro"

### Fixed -- wrap measured with the wrong widths

`width` takes an optional pdf object for exact metrics, and `wrap` passed
it at **one** of four places. The other three fell back to the
character-class estimate, which does not know the font. Measured with
DejaVu Sans as a CID font, "w35 Mo 17.08.26 CC Sped1" at size 8: 110.73
points exact against 89.44 estimated. A table in a CID font therefore
broke in the wrong place.

### Added -- text::fitSize and text::fits

`truncate` cuts, and sometimes that is the wrong answer: "Sped1" and
"Sped2" differ in the last character, so a shortened delivery note sends
the driver on the other tour. The same for two customers of one family,
and for numbers with decimals -- 12.12 cut is 12.1, which also exists.

`fitSize` returns the largest size at which the text still fits, down to
`-min` (default 6). Below that it stops and returns `-min`; the caller
decides whether to let it overhang or cut after all. `fits` is `width`
and the comparison in one.

Both grew out of a proposal from label printing; the measurements above
are from that.

### Added -- tests/test_tagging.tcl

Thirty-one tests. The first is the control that makes the rest worth
something: raw text plus a raw rectangle on a tagged document counts 2,
so a zero below really means "everything is in the tree" rather than
"nothing was drawn". Then each building block on its own -- paragraph,
table, charts, heading, labels, form fields -- and two documents that
combine them, one on a page, one across two pages. Finally the PDF/A
case: no warning, no standard font in the file, veraPDF PASS 2b. Twelve
more cover merged cells: the summary row, the two-level header, what is
*not* a cell spec, a cell spanning rows, the occupancy plan and the row
heights.

`labels::render` is checked with a callback that draws *raw* on purpose:
the frames and captions of a label sheet are decoration, and render has
to wrap them as artifacts, or every sticker counts.

### Added -- examples/advanced/66_pdfa_forms.tcl

A registration form with two text fields and two checkboxes at
`-pdfa 2b`, and it checks its own claim: pdf4tcl warnings, standard fonts
in the file, veraPDF. Exits non-zero when any of the three says no, so a
regression is a failed example rather than a quiet one.

### Added -- `-summary` on tables

`table::simpleTable` and `table::draw` take `-summary`, and `table::render`
reads a `summary` key from the dict form. It becomes the `/Summary`
attribute of the `Table` element: what the table shows and how it is built,
which a reader announces before the cells.

pdf4tcl takes the option from 0.9.4.56 on. Older versions raise on the
unknown option, `tag::begin` swallows that, and the table is still tagged --
only without the summary. Nothing is written when `-summary` is empty: a
`/Summary` with no text is worse than none, because a reader then announces
a table and says nothing about it.

### Changed -- `vendors/tm/` is gone

The directory held a byte-identical copy of every module, and nothing in
this repository read it. The projects that bundle pdf4tcllib -- mdstack,
mdhelp4 -- copy straight out of `lib/` into their **own** `vendors/tm/`,
as the handbook describes. The copy here only had to be kept in step:
`make sync` after every change, and a red `make check` when it was
forgotten.

`make sync`, `check` and `prune` go with it. `make test` is now the
default target, and `make conform` runs the veraPDF check.

### Changed -- module versions

    pdf4tcllib     0.6.1 -> 0.6.2 -> 0.6.3
    pdf4tcltable           0.3 -> 0.3.1
    pdf4tclcanvas          0.1 (new)
    pdf4tcltext            0.1 -> 0.2
    pdf4tcltreeview        0.1 (new)
    pdf4tclforms   0.2   -> 0.2.1 -> 0.2.2 -> 0.2.3
    pdf4tcllabels  0.1   -> 0.1.1

Not documentation: `fontMono` returns a different face and three
procedures carry a different default, so a caller who bundles the old
number and gets the new file would see changed behaviour under an
unchanged version.

### Added -- veraPDF cross-validation

`tools/check-conformance.sh` holds the generated PDFs against veraPDF.
It checks **only files that make a claim** -- the claim sits in the XMP
(`pdfaid`, `pdfuaid`), and the profile is read from there rather than
guessed. A file without a claim asserts nothing and cannot break; listing
it as failed would be wrong. Missing veraPDF or qpdf exits 0 with a note:
a missing tool is not a failure of the library.

The first run was unpleasant. Of four files that carried a claim, three
did not keep it:

    demo_45a_pdfa1b       1b    FAIL
    demo_45b_pdfa2b       2b    FAIL
    demo_45c_pdfa3b       3b    FAIL
    demo_65_tagged_table  ua1   PASS

`demo_65_tagged_table` passes PDF/UA-1 **and** PDF/A-3a, which is a good
result for the tagged-table work.

Two causes, both in `45_pdfa.tcl`. It set Helvetica -- ISO 19005 clause
6.3.4 wants every font program embedded, and the standard 14 have none, so
such a document always fails whatever else is right. And it called

    $pdf embedFile $tmpXml -description ... -mimetype "application/xml"

`embedFile` is the older route for a *visible* attachment and knows
neither option; its `switch` drops unknown ones silently. The call looked
right and did something else: the file carried `/Subtype /XML` instead of
the MIME type and failed clause 6.8. pdf4tcl itself is correct -- it
escapes the slash to `application#2Fxml` -- the value simply never
arrived. Now `addEmbeddedFile` with `-afrelationship Alternative`.

### Fixed -- the library forced the standard 14 on its callers

Eight examples already used `fonts::init` and named no standard font, so
they were one switch away from PDF/A. Setting `-pdfa 3b` on all eight left
two failing, and the cause was not in the examples.

* **Nine `setFont` calls with a hard-wired standard font** -- grid lines
  and coordinate labels in `pdf4tcllib`, the required-field asterisk in
  `pdf4tclforms`, label text in `pdf4tcllabels`. They now go through
  `fonts::`; without `init` they still return Helvetica and Courier, so
  nothing changes for existing callers.

* **Three defaults in argument lists** -- `drawing::textRotated`,
  `textScaled` and `textSkewed` carried `{font Helvetica}`. A search for
  `setFont Helvetica` does not find these, which is why they survived the
  first pass; they surfaced only after intercepting `setFont` at runtime
  and printing the caller. The default is now empty and falls back to
  `fonts::fontSans`.

* **`fontMono` was never set to a TrueType face.** `init` loaded the sans
  family and left `fontMono` at `Courier` in four places, even with
  `DejaVuSansMono.ttf` sitting beside the others. A document using
  monospace could therefore never be PDF/A. `init` now looks for
  `<family>Mono`, `DejaVuSansMono` or `LiberationMono-Regular`.

Result: 13 files carry a claim and all 13 keep it.

`tests/test_fonts.tcl` gains four tests for the state *after* `init`:
`fontSans` and `fontMono` must no longer be a standard font, and
`textRotated` must not carry a fixed default. The first attempt had six of
them **silently skipped** -- `testConstraint ttfAvailable` is evaluated at
the top of the file, before `init`, where it is always 0. A second
constraint is now set after `init`. A skipped test measures nothing and
still reports green.


### Docs -- the four new modules reach the howtos, tutorials and reference

The modules arrived with a reference page and one example each. What was
missing is everything around them:

* **`docs/en/tutorials/tutorial-02-full-report.md` + `.tcl`** -- the four
  modules working together: contents page, two-column body, chart, table,
  watermark on every page, in about eighty lines whose only pdf4tcl calls
  are `startPage`, `endPage` and `write`. Measured on the generated file:
  the five headings really are on pages 2, 3, 3, 4 and 4, the structure
  tree holds `TOC`, `TOCI`, `H1`, `H2`, `Figure`, `Table`/`TR`/`TH`/`TD`
  and `P`, six bookmarks, `getUntaggedCount` 0.
* **`docs/en/howtos/howto-charts.md` + `.tcl`** -- including the two things
  that go wrong: two charts side by side without a shared `-max` compare
  nothing, and tagging switched on halfway through leaves everything before
  it outside the tree. The script reported 35 loose drawing operations
  until the `tagged 1` call moved to the top; it reports 0 now.
* **`docs/en/howtos/howto-toc.md` + `.tcl`** -- the two-pass method and why
  the content script must not have side effects. The script checks itself:
  it reads every heading back with `pdftotext` and prints `mismatches: 0`.
* **`reference/accessibility.md`** -- the table of what each block marks up
  now covers `labels::render` (`Sect` per label), `toc::heading` and
  `toc::render` (`H1`..`H6`, `TOC`, `TOCI`), `chart::*` (`Figure` with
  alternate text) and `drawing::watermark` (Pagination artifact) -- with
  the limit stated plainly: `getUntaggedCount` counts what is unmarked,
  not what is understandable, so when the numbers matter, print them as a
  table as well.
* **`reference/API.md`** -- `drawing::watermark` documented, and the note
  about separate packages replaced by a table of all seven with links.

Also fixed: `docs/en/README.md` carried the Reference section **twice**,
once empty and once complete -- an append that had duplicated the heading
instead of filling it. One section now, with the new howtos and the
tutorial in it.

`run-all-examples.tcl` goes from OK=8 to **OK=11**, all green.

### Added -- pdf4tclflow: text through columns and pages

New module. `text::writeParagraph` sets one paragraph in one box; this is
the other thing -- a body of text that fills column one, continues in
column two and carries on at the top of the next page.

The page break is a script the caller supplies (`-newpage`), because only
the caller knows what a new page needs. **Without it the flow stops at the
last column and returns what is left in `rest`** rather than dropping it:
a report missing its last page and saying nothing about it looks exactly
like a complete one.

`measure` returns the wrapped lines with an empty string where a paragraph
ends. That empty string is the paragraph gap, and keeping it in the line
list is what makes the column arithmetic one loop instead of two -- a
column never starts with it, which is what would otherwise leave a stray
gap at the top of a column.

Measured, and contrary to what I assumed when writing the test: **more
columns do not save pages.** The same text took 3 pages in one column and
3 pages in three. Narrow columns break more often and leave more space at
every line end. The test now asserts what actually has to hold -- that
nothing is lost at any column count -- and says why.

### Added -- drawing::watermark

A diagonal stamp, fitted to the page diagonal by default, marked as a
`Pagination` artifact: it says something about the copy in your hand, not
about the text. Call it first on a page -- pdf4tcl has no alpha channel, so
it has to go underneath rather than over the content.

Verified by reading the text matrix out of the uncompressed stream: on A4
at 45 degrees `ENTWURF` comes out at 162.6 pt and both ends of the baseline
sit inside the page. Worth writing down: `pdftotext` returns rotated text
scrambled (`EN F TW U R`), so it cannot be used to check a watermark -- the
string is intact in the content stream.

23 tests, `examples/basic/42_columns.tcl`,
`docs/en/reference/pdf4tclflow.md`.

### Changed -- three German comments the translation pass had missed

`text::wrap` and `drawing::textRotated` carried German lines in the middle
of English blocks; the stop-word search had not caught them because the
surrounding text was English. Found while reading those two procedures for
the flow module.

### Added -- pdf4tclchart: bar, line and pie charts

New module, data-driven and Tk-free -- no canvas, no image, built on
`drawing::` and the pdf4tcl primitives.

```tcl
set y [::pdf4tcllib::chart::bar $pdf $x $y $w 190 \
    {Jan 120 Feb 145 Mar 98 Apr 160} -title "Revenue" -values 1]
```

Every command takes a box and returns the y below the chart, so charts
stack like paragraphs. Data comes as flat `label value` pairs or as a list
of pairs, and `line` also takes several series.

`niceScale` rounds the axis to something a reader can divide -- 137 becomes
150, not 137. The palette has six colours with distinct **lightness**, not
just distinct hue, so a chart survives being printed in grey.

With tagging on, a chart is one `Figure` element with an alternate text and
everything inside is a `Layout` artifact. That is the honest markup: a bar
chart is a picture of numbers. If the numbers matter to a reader, put them
in a table as well -- `getUntaggedCount` reports 0 either way, which is
exactly the limit of what it can tell you.

Verified by reading the numbers back out of the uncompressed content
stream rather than by looking at the picture:

    data          120    145     98    160
    bar height  86.52 104.55  70.66 115.36
    ratio      0.7210 0.7210 0.7210 0.7210

The ratio being constant is the test: a scale that swaps two bars, shifts
the zero line or gets the span wrong breaks it. 27 tests,
`examples/basic/41_charts.tcl`, `docs/en/reference/pdf4tclchart.md`.

Two of my own tests were wrong before the module was: counting every `l`
operator in the stream counts the grid lines too (10, not the 3 data
segments), and `/Artifact` lives in the content stream, so it is invisible
unless the document is written with `-compress 0`. Both now measure a
difference or read the right place.

### Added -- pdf4tcltoc: a table of contents with real page numbers

New module. The page number of a heading is known only after layout, and
putting the contents in front shifts every one of them, so the document is
laid out twice: once into a throwaway document to collect the headings,
once for real with the contents written first.

```tcl
::pdf4tcllib::toc::document $pdf a4 {
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Introduction"
    ...
} -title "Contents"
```

`heading` draws the heading with the matching structure type (`H1`..`H6`)
and adds a bookmark. The contents is a `TOC` element, each line a `TOCI`,
the dot leaders are `Layout` artifacts.

The two halves check each other: if the page count calculated before
writing differs from what `render` actually wrote, that is an error rather
than a document whose numbers point one page astray. That guard fired on
the very first run of the module and found the defect below.

Measured on a five-chapter document: the contents says pages 2, 2, 3, 4, 4
and `pdftotext` finds the headings on pages 2, 2, 3, 4, 4. `pageCount` and
`render` agree for 1, 5, 40, 43, 44, 45, 90 and 120 entries.

The content script runs **twice** and must not have side effects -- that is
inherent to the method and is documented at every entry point.

17 tests, `examples/basic/40_toc.tcl`,
`docs/en/reference/pdf4tcltoc.md`.

### Fixed -- writeParagraph returned a y from the wrong end of the page

`text::writeParagraph` has always documented "Returns the next Y position
after the last rendered line". It did not. It took the value from
`drawTextBox -newyvar`, which reports the position measured from the BOTTOM
of the page while the y passed in counts from the top. Measured with
pdf4tcl 0.9.4.43:

    y=200, one line at size 11    returned 633.5   correct is 216.0
    same, -orient 0               returned 10191.5 (the 10000 pt box
                                  height leaking into the result)

The offset was constant at any y, which is what made it identifiable: the
returned value is `pageHeight - (y + height)`.

Nobody had noticed because no caller in the tree used the return value --
`grep` finds zero. It surfaced while building the table of contents, which
is the first thing here that stacks text and needs to know where the last
paragraph ended.

The height now comes from `-linesvar`, which is orientation-free and
reports what was actually laid out, and the direction from
`$pdf cget -orient`. Both orientations verified.

### Added -- roll printer labels

`pdf4tcllabels` gains four roll formats -- Dymo 99012 and 11354, Zebra
100x150, Brother DK-11202 -- and `paper roll` for `define`. One label per
page, and the page *is* the label: `sheet` answers with the size in points
rather than a paper name, which is exactly the `{width height}` pair
pdf4tcl takes for `-paper`. The caller passes `[dict get $geo paper]` to
`startPage` either way and never has to know the difference; `render`,
`place` and `calibration` work unchanged. Measured: three labels give three
pages of 252 x 102 pt, which is 89 x 36 mm. A `roll` format with more than
one label per page is rejected.

Six tests. Also worth writing down, because it cost ten minutes: `#` is not
a comment inside the braces of `array set` -- a remark placed in the sheet
catalogue became two list elements and the module stopped loading with
"list must have an even number of elements".

---

## Unreleased -- cleanup

### Added -- tests for the two modules that had none

`pdf4tcllabels` and `pdf4tcltext` had no test file at all. 55 tests now
cover them, and writing them turned up two things:

* **`place` returned positions off the sheet.** `render` checks `-start`
  and `-only` against `perSheet`; `place` is exported, is shown directly in
  the howto, and answered position 24 of a 24-per-sheet form with the ninth
  row of an eight-row sheet (y = 839.1 pt), -1 with a row above the page.
  It now rejects anything outside `0..perSheet-1`.
* **Sheet 3475 did not fit an A4 page.** `top 4.5` plus six pitches plus one
  label height is 300.6 mm on a 297 mm sheet -- the last row printed 3.6 mm
  past the edge. Seven rows of 42.3 mm leave 0.9 mm for both margins, so
  `top` is 0.45. A new test checks every catalogue entry against its page,
  in both directions. **Check this against a real sheet before a long run:
  paper is the only measurement that counts here.**

One test taught rather than found: a Tk text widget is never empty -- it
always holds a trailing newline, so rendering one produces exactly one line.
The first version of that test expected y unchanged and was wrong.

### Fixed -- three examples were never checked by anything

`56_tablelist_pdf.tcl`, `57_textwidget_pdf.tcl` and
`58_tablelist_miscwidgets.tcl` export from a button and were marked `skip`
in the runner, so a full run reported success for three files nobody had
looked at. All three already had an `exportPDF` procedure and took the
output directory from `argv`, so the batch path was four lines each -- the
same `-batch` block 54 and 55 have had all along.

`58` needed more than that. Its header advertises that it finds
`miscWidgets_tile.tcl` automatically through `package ifneeded`; it does,
checks the file exists -- and then throws the result away and asks through
`tk_getOpenFile` anyway. The automatic detection was dead code, and the
modal dialog is why the demo hung rather than failed. The found path now
wins, the dialog appears only when there is nothing at that path, and under
`-batch` there is a message instead, because a dialog in a batch run is a
hang with a window on it.

    before   advanced: 30 OK / 3 Fehler / 3 interactive
    after    advanced: 32 OK / 4 Fehler / 0 interactive

The fourth failure is `58` reporting `can't find package combobox` -- the
tablelist demo it loads needs it. That is an environment gap like tkpath,
tko and cheatsheet, and it is now visible instead of skipped.

### Fixed -- orderTable drew past the edge of the page

`form::orderTable` documents its column widths as "sum <= SW" and nothing
checked it. Measured 2026-08-15: two columns of SW each produced a table
whose right edge sat at 1020 pt on a 595 pt page. Valid PDF, invisible
content, not a word from anyone -- qpdf is happy, the page is simply wider
than the paper.

It now refuses, and the message names both numbers, because "too wide" does
not help anyone do the arithmetic:

    orderTable: column widths total 963.8 pt, the text width is only
    481.9 pt -- the table would be drawn past the edge of the page

Half a point of tolerance for rounding. Fewer widths than headers is
rejected too. Nothing in the examples or tests hit either check.

### Fixed -- a spec with a list of sections blamed the library

`forms::renderSchema` takes `sections` as a dict, name -> section. Handed a
list of sections -- the obvious mistake, and the templates do not make the
difference visible -- `dict for` failed with a bare "missing value to go
with key" pointing into the library rather than at the caller's spec. It
now says what it wants. (I made exactly this mistake while writing the test
below, which is how it was found.)

### Added -- tests for the form helpers

`tests/test_formhelpers.tcl`, 24 tests. `test_forms.tcl` covers templates
and schema keys; the layer below it -- the geometry of the building blocks
and what actually lands in the file -- had none. These read `/Rect`, `/FT`
and `/T` back out of the generated PDF rather than trusting the call to
have worked:

* configuration arithmetic: `rowHeight` = `fieldHeight` + `rowGap`
* `orderTable`: the two new guards, `-cellForm` producing one field per
  cell, `-emptyRows` costing height
* `row`: a field never gets a width of zero or less, however long the
  label and however small the width -- the clamp described in the source
  comment now has a test
* `labelField`: text becomes `/FT /Tx`, checkbox becomes `/FT /Btn`
* `forms::field`: a field without a type is a text field; an unknown type
  is an error; a multiline field is taller
* `renderSchema`: y advances, the fields appear, both error paths

### Changed -- comments are English and pure ASCII

The remaining German comments in all five modules are translated: 54 blocks
in `pdf4tcllib`, 12 in `pdf4tclforms`, 9 in `pdf4tcltable`, 5 in
`pdf4tcltext`, 1 in `pdf4tcllabels`. Not a word of code changed -- proved
rather than asserted: with every comment line removed from both the old and
the new file, the two are byte-identical (3416 code lines in the main
module alone).

The ASCII check found three lines the German-word search had missed: an em
dash in `# High surrogate -- ...`, `# Hintergruende`, and an ellipsis
character in a `fdef:` example. Every module is now pure ASCII, which is
what the project rule asks for.

Left in place: `"Bundesanstalt fuer Immobilienaufgaben"` in
`pdf4tcllabels` -- a German authority name used as an example inside an
English sentence, and the point of the example is that it is wider than
70 mm.

### Changed -- messages are English, the page label is now settable

Eight German strings were left in the library. Seven are messages and are
now English, per the project rule (`form::configure`, `orderTable`,
`sumLine`, the paper size error, four `fonts::init` notices). One existing
test hung on the old German wording and was rewritten -- it now checks that
the message names the known paper sizes, which is what the caller needs.

The eighth was not a message: `page::footer` wrote a hardcoded German
`Seite N` **into the document**, while `page::number` right next to it
writes the language-free `- 3 / 10 -`. Changing that default would have
silently changed the language of every existing document, so it stays; it
is settable now, per call with `-pagelabel` or once via
`::pdf4tcllib::page::pageLabelFormat`. Measured: default `Seite 3`,
`-pagelabel "Page %s"` -> `Page 3`, namespace variable `p. %s` -> `p. 3`.
Four tests, and `footer` rejects an unknown option instead of ignoring it.

Not touched: about 108 German comments across the five modules. That is a
separate pass, and a mechanical translation without reading each one would
lose more than it gains.

### Docs -- pdf4tcllabels had no reference page

Every other module has one; the label module had two howtos and nothing
else, and neither `README.md` nor `API.md` mentioned it -- 0 occurrences of
the name in either. `docs/en/reference/pdf4tcllabels.md` documents the
catalogue, the five commands, the three text helpers and the tagging
behaviour, and `README.md` gets a section. Every table and every example in
it was run against the module rather than read out of the source comments;
the sheet table is printed from `sheet`, the sheet counts (1, 24, 25, 49
records -> 1, 1, 2, 3 sheets) come from `render`, and the tagged run
reports `/Document`, `/Sect`, `/P` with `getUntaggedCount` = 0.

### Fixed -- `-font` / `-boldfont` were accepted and ignored

The two per-call face overrides of `pdf4tcltable::render` and `renderRange`
went nowhere: 0.3 delegates drawing to `table::draw`, and nothing carried
them across. `table::draw` now takes `-fontreg` / `-fontbold`, `_dwFont`
takes an override dict, and the adapter passes the two options through.
Measured on the embedded font names of the output:

    no override                Helvetica, Helvetica-Bold
    -font Times-Roman          Times-Roman, Helvetica-Bold
    -boldfont Courier-Bold     Helvetica, Courier-Bold

Note for anyone who passed them before: they now take effect.

### Docs -- reference moved under docs/en/

The six reference documents (`API`, `accessibility`, `pdf4tclforms`,
`pdf4tcltable`, `pdf4tcltext`, `table-draw`) sat beside `docs/en/`, which
held the runnable howtos and tutorials. They are all English, so they now
live in `docs/en/reference/`, listed from `docs/en/README.md`. Nine links in
`README.md` and inside the documents moved with them; a link check over
every `.md` in the tree reports zero dead links (it found three left over
from the move, which are fixed).

### Fixed -- a collected run over a half-empty directory looked green

`runner::collect` replaces the bare `glob` in `run_basic.tcl` and
`run_advanced.tcl`. It warns when a directory holds fewer scripts than could
possibly be right. The case that prompted it: a misfiled copy of
`run_advanced.tcl` with three examples in the repository root, whose `glob`
found exactly those three and reported `2 OK / 0 Fehler` -- it looked like a
passed advanced run and had seen 3 of 36 scripts. A warning, not an error:
whoever empties a directory on purpose should be allowed to, and should see
it.

### Fixed -- five procedures accepted every option

`render`, `renderRange`, `simpleTable`, `renderSchema` and
`textwidget::render` all used the bare `array set opts $args` pattern: a
made-up option was stored and never read. Measured 2026-08-15,
`-quatsch 1` went through `pdf4tcltable::render` without a word. Each of
the five now checks the key against its own defaults and rejects an odd
number of option words. This matters most where an option exists but is
not applied -- `-font` / `-boldfont` in the 0.3 adapter -- because the
caller otherwise gets silence for an answer.

### Docs -- the 0.2 supplement was folded in

`docs/pdf4tcltable-0.2-footer-unicode.md` said in its own third line that
it should be folded into `docs/pdf4tcltable.md`. Two versions later it had
not been, and the consequence was real: `-footer`, `-footerbg` and
`-footerbold` exist in the 0.3 module but were missing from the option
table, so anyone reading the main document did not know the footer row
existed. Options, a `Footer row` section and a `Unicode` section are now in
`pdf4tcltable.md`; the supplement is removed. Nothing referenced it.

### Fixed -- the validator called an encrypted PDF broken

`tools/pdfvalidate.tcl` reported `demo_38_encrypted.pdf` as FAIL
("Incorrect password") -- a document that is password-protected on
purpose. Encryption is now reported as a skip, and `-password <pw>` hands
the password to qpdf, pdfinfo and pdffonts so the file can really be
checked (`-password benutzer` -> `PDF 1.5, 1 page(s), encrypted`).
Tcl's `child process exited abnormally` no longer leaks into the report,
where it used to land in the column meant for the file size.

---

## pdf4tcllib 0.6.1

### Fixed -- Tk was pulled in by every caller

`package require pdf4tcllib` loaded Tk, for one reason: the image helpers
measure a Tk photo with `[image width]`. The `catch {package require Tk}`
sat at module level, so every batch script got Tk whether it wanted it or
not.

The consequence is measured and unpleasant. `Tk_Init` registers a main
loop, and a script without a closing `exit` then waits for a window that
never comes. On a machine without a display nothing shows, because loading
Tk fails there and everything runs through. With `DISPLAY` set, eight
examples in `examples/advanced` hung indefinitely -- among them `45_pdfa.tcl`,
which has nothing to do with user interfaces.

Tk is now loaded by the three image procedures that need it, at call time.
Measured: those eight went from a 20-second timeout each to 0 seconds, and
`package require pdf4tcllib` no longer brings Tk with it.

### Fixed -- the example runner could not finish

`examples/advanced/run_advanced.tcl` picked its interpreter by name
(`tclsh`/`wish` from the PATH, so possibly a different Tcl generation than
the one running the suite) and ran each script through `exec` without a time
limit. Three examples export from a button in their window and cannot work
in a batch run at all; two others take `-batch` -- but the switch has to come
*after* the output directory, or the script takes it for one
("Written: -batch/demo_54...").

The runner now derives the interpreter from `[info nameofexecutable]`, runs
each script under `timeout` where the system has one, names the likely cause
when the limit hits, passes `-batch` to the two that know it, and skips the
three interactive ones with a reason.

`64_table_draw.tcl` treated its first argument as a file name while every
other example treats it as a directory. Called on its own that worked; in
the collected run it was handed a directory and failed to write. It takes a
directory now.

`d08_canvas.tcl` writes its file and then had nothing to end it; `exit 0`
added.

Measured with a display, `run_advanced.tcl`: from a 200-second hang to 6
seconds, 30 OK / 3 failed / 3 interactive. The three failures are missing
packages in the test environment (`tkpath`, `tko`, `cheatsheet`).

### Fixed -- the form builder left content outside the structure tree

pdf4tcl 0.9.4.43 counts painting operations that belong to neither a
structure element nor an artifact. Run against the form helpers it found
four, measured on a bare page each:

| helper | untagged operations |
|---|---|
| `form::labelField` | 1 -- the label |
| `form::row` | 1 per field -- the label |
| `form::section` | 3 -- bar, frame and title |
| `form::separator` | 1 -- the rule |

The fields themselves were attached correctly; what stood outside was the
text naming them. For a screen reader that is an input with no visible name
attached to it, and under ISO 14289-1 clause 7.1 it is a document that does
not meet the level it claims.

Two different remedies, because these are two different things:

- **Labels now sit inside the `Form` element they name.** `tag::begin` moved
  ahead of the label text in `labelField` and `row`, so the element holds the
  label and the field's `/OBJR`.
- **Decoration is marked as an artifact.** The section bar and frame and the
  separator rule go through `tag::artifact -type Layout`. Tagged as content
  they would be worse than untagged -- a reader announces the rules as if
  they meant something.

The section title is an `H2`: it heads the block it opens.

Measured after the change: all four helpers report zero, and a full form --
section, two labelled fields, a separator and a two-field row, claiming
PDF/UA and PDF/A-3b -- reports zero as well.

Nothing here changes the visible page.

---

## pdf4tcllib 0.6

`lib/pdf4tcllib-0.6.tm` (was `pdf4tcllib-0.5.tm`).

### Added -- tables carry a logical structure

Both table renderers mark up what they draw, so a screen reader announces a
table it can navigate by row and column instead of a run of unrelated
numbers:

- `table::render` -- the data-driven renderer with automatic page breaks
- `table::draw` -- the richer one, with footer, cell styles and row indent.
  `pdf4tcltable` (tablelist export) delegates to it, so that path is covered
  too without a change of its own. Verified against a real tablelist 7.11
  widget, not reasoned from the delegation: `table-tag-tablelist` exports one
  and checks the structure, `table-tag-tablelist-off` checks that nothing
  changes when tagging is off. Both skip cleanly where tablelist is absent.

The structure follows ISO 32000-1 clause 14.7:

    Table
      TR
        TH  (with /Scope Column)
      TR
        TD

A footer row is a `TR` of its own. Grid lines, background fills, borders and
zebra stripes become artifacts. Decoration announced as
content is worse than no tagging at all -- a reader would read out the
separators as if they meant something.

Header cells carry `/Scope Column` because ISO 14289-1 clause 7.5 wants it
wherever the relation between a header and its data cells cannot be derived
from the layout, which is the case for any table with a single header row.

### Added -- form fields are reachable from the tree

A form field is an annotation, and an annotation outside a structure element
cannot be reached: the field still works when clicked, but assistive
technology never finds it. All field-creating paths now wrap the field in a
`/Form` element -- the type ISO 32000-1 table 337 gives for an interactive
field -- with the label as alternate text:

- `pdf4tcllib::form::labelField`, `::row`, `::orderTable`, `::sumLine`
- `pdf4tclforms::_addForm` and the three that bypass it: radio buttons,
  push buttons, signature fields

The measure is pdf4tcl's own warning from 0.9.4.39: it fires for an
annotation left out of the tree, and it falls silent once the field is
wrapped. `form-tag-no-warning` asserts exactly that, rather than checking for
the presence of a string.

Verified on the three demo forms in `examples/advanced/60_*`:
`check-tagged.py` reports no failures where it previously reported twenty.

**This needs pdf4tcl 0.9.4.42.** `/Form` was accepted by `tagBegin` but not
by the annotation attachment, which only knew `Link` and `Annot` -- so the
element sat in the tree while the field stayed unreachable, and the warning
fired for a document that had done everything right.

### Not switched on here

Tagging stays the caller's decision:

```tcl
$pdf tagged 1 -lang de-DE
```

Without it every helper does nothing, so existing code is unaffected -- the
suite passes unchanged, and a document built without `tagged` contains no
marked content and no structure tree at all. That is checked by
`table-tag-off`.

Detection is by asking rather than by version number, so a pdf4tcl older than
0.9.4.36 needs no special case. `tagArtifact` is the probe: it raises the
same "tagging is not enabled" as `tagBegin` when off, but creates no
structure element when on. The first attempt used a `tagBegin`/`tagEnd` pair
and left an empty `Span` sitting in the tree next to every table -- measured,
not reasoned. `table-tag-noprobe` guards against it coming back.

### Requires

pdf4tcl 0.9.4.36 or later for the tagging to have an effect; older versions
work as before.

---

## pdf4tcllib 0.5

`lib/pdf4tcllib-0.5.tm` (was `pdf4tcllib-0.4.tm`).

### Changed — the formula engine is backend-neutral

- `pdf4tcllib::math` no longer speaks to pdf4tcl directly. Measuring and drawing
  now go through a **backend**: a command prefix understanding three operations
  and nothing else.

  ```
  {*}$be width $font $size $text         -> width of $text
  {*}$be text  $font $size $x $y $text   -> draw, baseline at $y
  {*}$be line  $x1 $y1 $x2 $y2 $width    -> draw a line
  ```

  Both coordinate systems agree (y grows downward in pdf4tcl *and* on the Tk
  canvas), so the same geometry serves both.

- Two backends ship: `math::pdfBackend $pdf` (the previous behaviour) and
  `math::canvasBackend $canvas ?-family? ?-fill? ?-tags?`. New public entry
  points `math::measureLatexOn` / `math::renderLatexOn` take a backend; the old
  `measureLatex` / `renderLatex` keep their pdf4tcl signature and are now thin
  wrappers, so existing callers (docir::pdf) are unaffected.
- The canvas backend rounds the font size once, in `_canvasFont`, so measuring
  and drawing stay consistent, and shifts text by the font's descent — the Tk
  canvas has no baseline anchor, `sw` is one descent below it.
- Consequence: the LaTeX subset (`\frac`, `\sqrt`, scripts, big operators) is
  no longer PDF-only. `docir::rendererTk` 0.4 typesets display math in the Tk
  viewer through the canvas backend.

### Added

- `tests/test_math.tcl` — 13 tests across three backends: PDF, a **recording
  backend** (logs the primitives, needs neither Tk nor PDF, so what the engine
  *draws* is testable, not just that it does not crash), and the Tk canvas.

---

## pdf4tclforms 0.1.2

### Added
- New field types `radio` (radio-button group: `group`,
  `options {{value label} ...}`, optional preselected `init`) and `buttons`
  (horizontal push-button bar, `items {{id caption action ?url?} ...}`, for
  Submit/Reset).
- Editable combobox (`editable`), multi-select and sorted listbox
  (`multiselect`/`sort`), and a `signature` field type (`placeholder`,
  `fieldh`, `readonly`).

### Changed
- `sums` entries gained `id`/`calculate`/`over`/`format`/`js` for live,
  currency-formatted (and JS-computed, e.g. VAT/total) sum lines;
  `over {idPrefix col count}` totals an editable table column.
- Field keys `align`/`color`/`border*`/`bgcolor`/`calculate`/`format`/`js`
  are passed through to `addForm` for single fields, `row` fields and editable
  table columns (the table `columns` key). Requires pdf4tcl 0.9.4.34+.

### Fixed
- Multiline fields put the label on its own line above and the field at full
  width below (a long label no longer runs into the field box); demo 62
  (`Fehlermeldung`) spans multiple pages with `-pagebreak 1`.

---

## pdf4tcllib 0.3

### Added

#### `pdf4tcllib::text` -- inline math primitives
- `text::superscript pdf str x y size font` -- raised text at 70% size,
  0.35x baseline shift up. Returns rendered width.
- `text::subscript pdf str x y size font` -- analogous below baseline,
  0.20x shift down.
- `text::mathSymbol name` -- LaTeX-name -> Unicode lookup. 67 symbols
  including Greek lower/upper (alpha-omega, Alpha-Omega), operators
  (cdot, times, pm, div), comparison (le, ge, ne, approx, equiv),
  big symbols (sum, prod, int, partial, nabla, sqrt, infty), arrows
  (rightarrow, leftarrow, Rightarrow, Leftarrow), set theory (in,
  notin, subset, supset, cup, cap, emptyset), logic (forall, exists).
  Unknown names return empty string.
- `text::mathSymbolNames` -- sorted list of all available names.

#### `pdf4tcllib::fonts` -- CID-mode for full Unicode
- New option `fonts::init -cid 1` -- registers fonts via
  `pdf4tcl::createFontSpecCID` (Identity-H encoding, full TTF embedded)
  instead of the default 256-character subset.
- `fonts::isCidMode` -- query the active encoding mode (1 = CID, 0 = subset).
- `unicode::sanitize` Stage 2 bypasses the subset filter when CID-mode
  is active, so Greek letters and math symbols render correctly instead
  of being replaced with `?`.

#### `pdf4tcllib::math` -- new module
Port of Arjen Markus' MathFormula from the Tcler's Wiki (2002-2007)
to PDF output. Two public procs:
- `math::renderFormula pdf x y formula ?-size N? ?-font NAME?` --
  renders eqn-notation formulae (space-separated tokens). Returns
  end X-position.
- `math::analyseFormula formula` -- exposed token parser, useful for
  custom renderers.

Notation: `^` superscript, `_` subscript, `~` forced space, Greek
names (`alpha beta`), big operators (`SUM INT PROD` with `from`/`to`
limits), math symbols (`infty sqrt cdot le ge approx ...`), arrows
(`rightarrow leftarrow`).

Three corrections vs. Arjen's 2002 Wiki version:
- `infty` instead of `Inf` (LaTeX-consistent, matches `mathSymbol`).
- Greek codepoints fixed (`PI \u400` etc. were Cyrillic typos --
  now correct `U+03A0` etc.).
- `to` is always a limit-keyword (after SUM/INT/PROD); use
  `rightarrow` for the right-arrow symbol.

Requires `fonts::init -cid 1` to render Greek and math symbols.

#### Tests
- `tests/test_text.tcl` -- 9 new tests for math primitives. Total
  39/39 passes (was 30/30).

#### Examples
- `examples/advanced/math_inline_demo.tcl` -- demonstrates
  superscript, subscript, and mathSymbol with formulae like
  H2O, E=mc^2, alpha_i^2 + beta_i^2.
- `examples/advanced/math_formula_demo.tcl` -- portation of the
  Wiki examples plus additions (quadratic formula, Euler's identity,
  chemical reactions). 14 formulae in one PDF.

#### Documentation
- `docs/API.md` -- new `math` section, expanded `fonts` section with
  CID-mode reference, expanded `text` section covering all helper
  procs (expandTabs, detectFont, superscript, subscript, mathSymbol,
  mathSymbolNames). Module-overview table updated.
- `README.md` -- new modules-section entry for `math`, fonts entry
  expanded with CID-mode note, text entry expanded with math helpers.
- `CHANGELOG.md` -- this file.

### Changed
- `tests/run_all.tcl` -- now requires `pdf4tcllib 0.2` (was 0.1, stale).
- `form::orderTable` -- new `-cellForm idPrefix` option renders each body cell
  (data rows *and* empty rows) as a fillable AcroForm text field
  (`id = idPrefix_row_col`) instead of static text. This makes `orderTable`
  the single table renderer for both static and editable tables. The static
  path is byte-for-byte unchanged (verified: 0-pixel diff old vs new incl.
  long-text truncation, data rows and empty rows).
- `form::sumLine` -- optional `-id`/`-calculate`/`-init`/`-format`/`-js`: the
  value cell can be a right-aligned calculated form field (live sum via
  `AFSimple_Calculate`, `/CO` + `/NeedAppearances`), number-formatted
  (`AFNumber_Format`) or driven by raw JavaScript. Needs pdf4tcl 0.9.4.32+
  (`-format` 0.9.4.33+, `-js` 0.9.4.34+). Existing 5-argument calls unchanged.
- `form::orderTable` -- new `-cellOpts {col {opts} …}`: per-column addForm
  options for editable cells (e.g. right-aligned, currency-formatted amount
  columns). Exposed by pdf4tclforms as the table `columns` key.

### Fixed
- Form labels/titles/headers/sum values now go through
  `unicode::safeText`, so text with characters beyond Latin-1 (e.g. the Euro
  sign in a label) no longer aborts rendering -- especially on Tcl 9, where such
  code points are rejected on the binary channel. Plain Latin-1 labels are
  byte-for-byte unchanged (0-pixel diff verified). Applies to `form::section`,
  `labelField`, `row`, `orderTable` (headers + static cells), `sumLine`, and the
  pdf4tclforms field/checkbox/radio renderers.

- `unicode::safeText` -- the emergency ASCII reduction (non-ASCII -> `?`)
  and a total failure of the fallback `$pdf text` call were swallowed
  silently. Both now emit a one-time stderr warning (`_warnOnce`), so
  character substitution and "text not drawn" no longer pass unnoticed.
- `math::_latexSymbol` -- an unknown LaTeX command that falls through to its
  raw name now emits a one-time warning per symbol instead of rendering it
  silently as literal text.
- `form::row` -- used `dict getdef`, which is Tcl 8.7/9+ only, so the whole
  `form::` layer crashed on Tcl 8.6. Replaced with a compatibility shim
  `::pdf4tcllib::_dictGetdef` (single-key). Verified on 8.6.14 and 9.0.2.
- `form::` procs (`configure`, `section`, `labelField`, `row`, `separator`,
  `orderTable`, `sumLine`, `fieldHeight`, `rowHeight`) are now exported, so
  they can be reached via `namespace import` -- not just fully qualified.
- `form::row` -- the label column was a fixed `CFG(labelW)` (90pt). With the
  small per-pair `width` values that the form schemas use, this left the field
  0pt or negative wide, so the field box overwrote the next pair's label
  (visible in the callnote/order templates and demos 61/62). The label column
  now sizes to the actual label text width (explicit `labelw` still wins), the
  field width is clamped to a sane minimum, and the pair advance never
  underruns the drawn content.

---

## pdf4tcllib 0.2

Educational/training library for pdf4tcl, single-file `.tm` deployment.

### Modules consolidated
Nine modules merged into one `pdf4tcllib-0.2.tm`:

- `units` -- mm/cm/inch <-> points
- `fonts` -- TTF auto-discovery (Linux, Windows, macOS)
- `unicode` -- glyph safety, no-crash on special chars
- `text` -- wrap, width, truncate, detectFont, expandTabs
- `page` -- PageContext, header, footer, page numbers
- `table` -- headers, zebra, auto page-break
- `drawing` -- gradients, polygons, stars, rotation
- `image` -- image helpers
- `form` -- label+field, sections, order tables

### Dependencies
- `pdf4tcl` >= 0.9.4.x (TrueType font loading + Unicode CID support)

### Tests
8 test files in `tests/`, run via `tclsh tests/run_all.tcl`.

### Compatibility
- Legacy wrappers (`cheatsheet-0.1.tm`, `pdf4tcltable-0.1.tm`,
  `pdf4tcltext-0.1.tm`) retained for backward compatibility but their
  functionality is integrated into `pdf4tcllib-0.2.tm`.

---

## pdf4tcllib 0.1

Per-module split: `pdf4tcltext-0.1.tm`, `pdf4tcltable-0.1.tm`,
`cheatsheet-0.1.tm`. Foundation for 0.2 consolidation.
