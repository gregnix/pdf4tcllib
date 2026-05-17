# pdf4tcllib Changelog

Notable changes per release. Pre-0.2 history reconstructed from git log
and module headers.

---

## 0.3 (planned)

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

---

## 0.2 (current)

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

## 0.1 (initial)

Per-module split: `pdf4tcltext-0.1.tm`, `pdf4tcltable-0.1.tm`,
`cheatsheet-0.1.tm`. Foundation for 0.2 consolidation.
