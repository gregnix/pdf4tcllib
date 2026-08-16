# pdf4tcllib Changelog

Notable changes per release. Pre-0.2 history reconstructed from git log
and module headers.

---

## Unreleased -- features

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
