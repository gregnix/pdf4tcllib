# How to make a contents page whose numbers are right

With `pdf4tcltoc`. Run the script beside this file:

```
tclsh howto-toc.tcl [outdir]
```

It prints the contents it generated and then checks every entry against the
document with `pdftotext`. On the sandbox it ends with `mismatches: 0`.

---

## Why this is not simply "write the headings down"

The page number of a heading is only known once the document has been laid
out. Putting the contents in front of the document then shifts every one of
those numbers by the length of the contents itself -- and if that pushes
the contents onto a second page, they shift again.

There is no way round laying the document out twice, and that is what
`toc::document` does.

---

## The content is a script

```tcl
set content {
    $pdf startPage
    set y [dict get $ctx top]
    foreach ch $chapters {
        lassign $ch level title
        ::pdf4tcllib::toc::heading $pdf $ctx y $level $title
        ...
    }
    $pdf endPage
}

set result [::pdf4tcllib::toc::document $pdf a4 $content -title "Contents"]
```

The script sees two variables of its own, `pdf` and `ctx`, and starts its
own pages. `toc::document` does not lay out the body -- it only runs this
script, twice.

**So the script must not have side effects.** No appending to a file, no
counter that survives from the first run into the second, nothing read from
a channel it consumes. Anything stateful has to be reset at the top of the
script, where it will be reset again on the second run.

That is the one thing that catches people out. If a running head counts
pages, reset the counter in the script; do not increment a variable that
lives outside it.

---

## `toc::heading` does three things at once

```tcl
::pdf4tcllib::toc::heading $pdf $ctx y 2 "Page layout"
```

* draws the heading, with the structure type for its level (`H2` here) and
  a font size derived from it
* records title and page -- but only during the first run
* adds a PDF bookmark at the matching nesting level

Outside a collecting run it still draws. It is a normal heading command
that happens to remember things when someone is listening.

---

## The page break stays yours

The script above breaks pages itself:

```tcl
if {$y > [dict get $ctx bottom] - 70} {
    $pdf endPage
    $pdf startPage
    set y [dict get $ctx top]
}
```

Nothing in the module decides where a page ends. That is deliberate: a
running head, a watermark, a chapter that must start on a right-hand page
are all things only the caller knows about. See
[`../tutorials/tutorial-02-full-report.md`](../tutorials/tutorial-02-full-report.md)
for a version where the page break is a procedure shared with the column
flow.

---

## What comes back

```tcl
dict get $result entries      ;# {level title page} per heading
dict get $result tocPages     ;# pages the contents took
dict get $result contentPages ;# pages the content took
```

The page numbers in `entries` are the final ones -- already shifted past
the contents.

---

## The check the module does for you

Before writing anything, `toc::document` calculates how many pages the
contents will need; afterwards it compares that against how many were
actually written. If the two disagree, it raises an error instead of
producing a document whose numbers all point one page astray.

That guard is not decoration: it fired on the very first run of the module
during development and turned out to be pointing at a bug in
`text::writeParagraph` rather than in the arithmetic.

---

## Options worth knowing

| option | |
|---|---|
| `-title` | heading of the contents page; `Contents` by default |
| `-leader` | the dot character; `""` for no leaders |
| `-indent` | points per level |
| `-bookmarks 0` | draw the contents but add no bookmarks |
| `-size`, `-titlesize` | font sizes |

With tagging on, the contents is a `TOC` element, each line a `TOCI`, and
the dot leaders are `Layout` artifacts -- a reader announces the entry, not
a row of dots.

---

## See also

* [`../reference/pdf4tcltoc.md`](../reference/pdf4tcltoc.md)
* [`../tutorials/tutorial-02-full-report.md`](../tutorials/tutorial-02-full-report.md)
  -- contents, columns, charts and a watermark in one document
