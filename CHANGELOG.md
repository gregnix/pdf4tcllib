# pdf4tcllib Changelog

Notable changes per release. Pre-0.2 history reconstructed from git log
and module headers.

---

## 0.3 (planned)

### Added
- `pdf4tcllib::text::superscript` -- draws text raised above baseline at
  reduced font size (typical: 0.7x size, y-shift 0.5*size up).
- `pdf4tcllib::text::subscript` -- analogous below baseline.
- `pdf4tcllib::text::mathSymbol` -- name-to-Unicode lookup table
  (`alpha` -> `α`, `cdot` -> `·`, `le` -> `≤`, ...). Covers common LaTeX
  symbol names used in inline math.
- `tests/test_text.tcl` -- new tests for the three additions.

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
