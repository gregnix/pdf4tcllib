# pdf4tcllib Changelog

Notable changes per release. Pre-0.2 history reconstructed from git log
and module headers.

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
