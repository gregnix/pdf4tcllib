# pdf4tclflow -- Text Through Columns and Pages

`text::writeParagraph` sets one paragraph in one box. This is the other
thing: a body of text that fills column one, continues in column two, and
carries on at the top of the next page.

```tcl
package require pdf4tclflow

set result [::pdf4tcllib::flow::columns $pdf $ctx $body -columns 2 -newpage {
    $pdf endPage
    $pdf startPage
    ::pdf4tcllib::page::header $pdf $ctx "Chapter 1"
}]
```

---

## The page break belongs to the caller

`-newpage` is a script, run whenever the last column is full. It must leave
a page open. Everything a new page needs -- a running head, a watermark, a
rule along the top, a different layout for a chapter opening -- goes in
there, because only the caller knows what that is.

**Without `-newpage` the flow stops when it runs out of columns and returns
what is left in `rest`.** It does not drop it. Silence would be the worse
answer: a report missing its last page and saying nothing about it looks
exactly like a complete one.

---

## Commands

### `columns pdf ctx text ?option value ...?`

Flows `text` through the columns. Paragraphs are separated by a blank line;
whitespace inside a paragraph is collapsed. Returns a dict:

| key | |
|---|---|
| `column` | the column the text ended in, 0-based |
| `y` | the y below the last line |
| `pages` | how many page breaks were made |
| `lines` | how many lines were set |
| `rest` | what did not fit; empty when everything was set |

| option | default | |
|---|---|---|
| `-columns` | 2 | number of columns |
| `-gap` | 18 | space between columns, in points |
| `-size` | 10 | font size |
| `-font` | from `fonts::init` | |
| `-tag` | `P` | structure type the text is wrapped in; `""` for none |
| `-top` `-bottom` | from `ctx` | where a column starts and ends |
| `-firsty` | `-top` | start the first column lower, e.g. below a heading |
| `-newpage` | `{}` | script for the page break |

### `boxes ctx ?options?`

Returns `{x width}` per column. Public because a caller who wants to place
a picture in column two needs the same arithmetic.

### `measure pdf text width size font`

The lines the text makes at that width: the wrapped lines, with an empty
string where a paragraph ends. That empty string is the paragraph gap, and
keeping it in the line list is what makes the column arithmetic one loop
instead of two.

---

## What columns do not buy you

Measured, and worth knowing before choosing a layout: **more columns do not
save pages.** The same text set in one column took 3 pages; in three
columns it also took 3. Narrow columns break more often and leave more
space at every line end, and that eats the gain.

Columns are a matter of readability -- a line of 60 to 80 characters is
easier to read than one of 130 -- not of density.

---

## drawing::watermark

Lives in `pdf4tcllib` proper, next to the other drawing helpers, and is
documented here because it is what a flowed report usually wants on every
page.

```tcl
::pdf4tcllib::drawing::watermark $pdf $ctx "DRAFT"
```

**Call it first on a page.** It draws in plain grey with no transparency,
so whatever is drawn afterwards sits on top of it. pdf4tcl has no alpha
channel, and faking one by drawing over the content would hide the content.

| option | default | |
|---|---|---|
| `-angle` | 45 | degrees, counter-clockwise |
| `-size` | 0 | 0 fits the text to the page diagonal |
| `-color` | light grey | dark enough to see, light enough to read through |
| `-font` | from `fonts::init` | |

Returns the font size used, which is the interesting number when the text
was fitted: on A4 at 45 degrees, `ENTWURF` comes out at about 163 pt.

The stamp is a `Pagination` artifact. It says something about the copy in
your hand, not about the text -- a reader announcing "DRAFT" in the middle
of a sentence would be worse than not hearing it at all.

> `pdftotext` returns rotated text scrambled (`EN F TW U R`). That is the
> extractor, not the document: in the content stream the string is intact.
> Do not use `pdftotext` to check a watermark.

---

## See also

* [`API.md`](API.md) -- `text::writeParagraph` for a single paragraph,
  `page::context`
* [`pdf4tcltoc.md`](pdf4tcltoc.md) -- headings and a contents page for the
  same document
