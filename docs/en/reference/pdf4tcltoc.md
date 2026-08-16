# pdf4tcltoc -- Table of Contents

A contents page with real page numbers, and a bookmark per heading.

```tcl
package require pdf4tcltoc

set pdf [::pdf4tcl::new %AUTO% -paper a4]
set result [::pdf4tcllib::toc::document $pdf a4 {
    $pdf startPage
    set y [dict get $ctx top]
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Introduction"
    set y [::pdf4tcllib::text::writeParagraph $pdf $body \
            [dict get $ctx left] $y [dict get $ctx text_w] 11]
    $pdf endPage
} -title "Contents"]
$pdf write -file manual.pdf
```

---

## Why the content script runs twice

The page number of a heading is only known once the document has been laid
out -- and putting the contents in front of it shifts every one of those
numbers by the length of the contents itself. There is no way around laying
the document out twice:

| pass | |
|---|---|
| 1 | the script runs into a **throwaway** document; every `heading` records its title and the page it landed on |
| 2 | the contents is written into the real document first, then the script runs again for real |

Two consequences the caller has to live with:

* **The script must not have side effects.** No appending to a file, no
  counters outside it, no reading from a channel it consumes. It runs
  twice, and only the second run ends up in the document.
* **Content that depends on the current page number changes between the
  passes.** A running head reading "page 3 of 12" will be right, because it
  is drawn during the second pass; something that measured itself during
  the first will not.

The two runs are checked against each other: if the number of contents
pages calculated up front differs from what was actually written, that is
an error rather than a document whose numbers point one page astray.

---

## Commands

All commands live in `::pdf4tcllib::toc`.

### `document pdf paper script ?option value ...?`

The whole two-pass run. `script` runs in the caller's scope and sees two
variables:

| | |
|---|---|
| `pdf` | the document to draw into -- the throwaway one in pass 1 |
| `ctx` | the `page::context` for `paper` |

The script starts and ends its own pages. Returns a dict:

| key | |
|---|---|
| `entries` | the collected headings, `{level title page}`, page numbers already shifted past the contents |
| `tocPages` | how many pages the contents took |
| `contentPages` | how many pages the content took |

Options:

| option | default | |
|---|---|---|
| `-title` | `Contents` | heading of the contents page |
| `-titlesize` | 16 | its font size |
| `-size` | 11 | font size of the entries |
| `-leader` | `.` | character used for the dot leader; `""` for none |
| `-indent` | 14 | indent per level, in points |
| `-gap` | 4 | gap below a heading, in points |
| `-bookmarks` | 1 | add a PDF bookmark per heading |

### `heading pdf ctx yVar level text ?option value ...?`

Draws a heading and records it. `level` is 1..6 and decides three things at
once: the structure type (`H1`..`H6`), the default font size (18 minus 2
per level, floored at 10) and the indent in the contents.

Advances `yVar` past the heading and returns the new y.

| option | |
|---|---|
| `-size` | font size, overriding the default for the level |
| `-tag` | structure type, overriding `H<level>` |
| `-gap` | gap below this heading |

Outside a collecting run the procedure still draws -- it is a normal
heading command, and nothing is recorded.

### `collect script ?offset?`

Runs `script` in collecting mode and returns the entries. `offset` is added
to every page number. `document` uses this; it is public for a caller who
lays out the passes by hand.

The collecting flag is cleared even when the script fails.

### `render pdf ctx entries ?option value ...?`

Writes the contents pages and returns how many it wrote. Opens and closes
its own pages. Takes the same options as `document`.

### `pageCount ctx entries ?option value ...?`

How many pages `render` will need -- the number that decides every page
number, so it has to be known before anything is written. `document`
compares it against what `render` actually wrote.

### `entries`

The entries of the most recent collection.

### `configure ?option value ...?`

Read or set the defaults for all of the above.

---

## Tagging

With `$pdf tagged 1` the contents is marked up as one would want it read:

* the whole contents is a `TOC` element
* each line is a `TOCI` -- one item, not three loose runs of text
* the dot leaders are a `Layout` artifact, so a reader does not announce a
  row of dots
* headings carry `H1`..`H6` according to their level

---

## Measured

From the test suite, on a five-chapter document with page breaks:

```
contents says   Einleitung 2, Grundlagen 2, Aufbau 3, Betrieb 4, Anhang 4
pdftotext finds them on pages 2, 2, 3, 4, 4
bookmarks       5, one per heading
```

`pageCount` and `render` are checked against each other for 1, 5, 40, 43,
44, 45, 90 and 120 entries -- the interesting lengths are the ones either
side of a page boundary.

---

## See also

* [`API.md`](API.md) -- `page::context`, `text::writeParagraph`
* [`accessibility.md`](accessibility.md) -- what the tagging above buys and
  what it does not
