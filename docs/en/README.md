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
| [`tutorial-02-full-report.md`](tutorials/tutorial-02-full-report.md) | Everything together: contents page, two-column body, charts, table, watermark |

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
| [`howto-charts.md`](howtos/howto-charts.md) | Numbers on a page: bars, lines, shares, and a shared scale |
| [`howto-toc.md`](howtos/howto-toc.md) | A contents page whose numbers are right |

## Reference

The module documentation. These describe the API; the howtos above show it
in use.

| | |
|---|---|
| [`reference/API.md`](reference/API.md) | pdf4tcllib -- the full API |
| [`reference/table-draw.md`](reference/table-draw.md) | `table::draw` -- data-driven tables, Tk-free |
| [`reference/pdf4tcltable.md`](reference/pdf4tcltable.md) | `pdf4tcltable` -- export a tablelist widget |
| [`reference/pdf4tcltext.md`](reference/pdf4tcltext.md) | `pdf4tcltext` -- export a Tk text widget |
| [`reference/pdf4tclforms.md`](reference/pdf4tclforms.md) | `pdf4tclforms` -- declarative fillable forms |
| [`reference/pdf4tcllabels.md`](reference/pdf4tcllabels.md) | `pdf4tcllabels` -- label sheets, calibration, text fitting |
| [`reference/pdf4tcltoc.md`](reference/pdf4tcltoc.md) | `pdf4tcltoc` -- table of contents with real page numbers |
| [`reference/pdf4tclchart.md`](reference/pdf4tclchart.md) | `pdf4tclchart` -- bar, line and pie charts |
| [`reference/pdf4tclflow.md`](reference/pdf4tclflow.md) | `pdf4tclflow` -- text through columns and pages, plus the watermark |
| [`reference/accessibility.md`](reference/accessibility.md) | What an accessible document needs, and what no tool can supply |

## Requirements

pdf4tcllib 0.6.1 with pdf4tcl 0.9.4.43. Older pdf4tcl keeps working, but
`getUntaggedCount` and the structure checks arrived in 0.9.4.43, and the
scripts here report on them.

A TrueType font is needed for anything that claims PDF/UA -- the scripts
look for DejaVu, FreeSans and Arial in the usual places and say so when
they find none.

