# pdf4tcllib -- howtos and tutorials

Every script here runs. They were executed, not written and hoped for, and
each one ends by reporting how much of its own content it left outside the
structure tree -- zero is the point of the exercise.

```bash
tclsh docs/en/run-all-examples.tcl          # all of them
tclsh docs/en/howtos/howto-tagged-table.tcl # one of them
```

PDFs land in `docs/en/out/`. Pass a directory as the first argument to
write somewhere else.

Scripts that need Tk and a display say so and exit 0 when they have
neither; the runner counts those as skipped, not as passes. Start a display
first to run them:

```bash
Xvfb :99 -screen 0 1280x1024x24 & export DISPLAY=:99
```

## Tutorials

| | |
|---|---|
| [`tutorial-01-accessible-report.md`](tutorials/tutorial-01-accessible-report.md) | A report that is accessible from the first line: font, language, headings, table, caption |

## Howtos

| | |
|---|---|
| [`howto-tagged-table.md`](howtos/howto-tagged-table.md) | A table a screen reader can navigate |
| [`howto-accessible-form.md`](howtos/howto-accessible-form.md) | A form whose fields have names |
| [`howto-long-table.md`](howtos/howto-long-table.md) | A table over several pages, headers repeated as headers |
| [`howto-images.md`](howtos/howto-images.md) | Images, and the alternate text no tool can supply |
| [`howto-tablelist-export.md`](howtos/howto-tablelist-export.md) | Export a tablelist widget, display order and all |
| [`howto-label-sheets.md`](howtos/howto-label-sheets.md) | Label sheets: Zweckform formats, part-used sheets, "1 von 4" |
| [`howto-shipping-labels.md`](howtos/howto-shipping-labels.md) | Parcel labels: sorting by tour, what goes where, the barcode |

## Reference

| | |
|---|---|
| [`../accessibility.md`](../accessibility.md) | What each block marks up, what stays your job, how to check |
| [`../API.md`](../API.md) | The full API |

## Requirements

pdf4tcllib 0.6.1 with pdf4tcl 0.9.4.43. Older pdf4tcl keeps working, but
`getUntaggedCount` and the structure checks arrived in 0.9.4.43, and the
scripts here report on them.

A TrueType font is needed for anything that claims PDF/UA -- the scripts
look for DejaVu, FreeSans and Arial in the usual places and say so when
they find none.
