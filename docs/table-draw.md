# pdf4tcllib::table::draw — Data-driven table renderer (Tk-free)

**Package:** `pdf4tcllib 0.4+` · **Namespace:** `::pdf4tcllib::table`

`table::draw` renders a table from plain data (no widgets, no Tk) straight
into a pdf4tcl object. It sits on top of the existing engine
(`fonts` / `text` / `unicode`) and complements `table::render` and
`table::simpleTable` without changing them. As of `pdf4tcltable 0.3` the
tablelist widget exporter is a thin adapter over `table::draw`.

---

## Call

```tcl
::pdf4tcllib::table::draw pdf x y cols data ?option value ...?
```

Draws starting at (`x`, `y`) and returns the **next Y position**.

- **cols** — a list with one option list per column:
  `{-header "Text" -width auto|<pt> -align left|center|right -font reg|bold|italic|mono}`
- **data** — a list of rows; each row a list of **plain cell strings**.

Styles are **not** mixed into `data`; they are addressed by index
(`-cellstyles` / `-rowstyles`), which is collision-free and mirrors
tablelist's `cellconfigure` / `rowconfigure`.

---

## Options

| Option | Default | Meaning |
|--------|---------|---------|
| `-ctx <dict>` | — | `page::context` dict → **automatic page breaks** (header repeated per page) |
| `-maxwidth <pt>` | from `-ctx` / 480 | Table width; fixed column widths are scaled down proportionally if their sum exceeds it |
| `-header 0\|1` | 1 | Draw the header row |
| `-headerbg {r g b}` | light blue | Header background (0–1) |
| `-headerfg {r g b}` | `{0 0 0}` | Header text color |
| `-zebra 0\|1` | 0 | Alternating row backgrounds |
| `-zebracolor {r g b}` | light gray | Zebra color |
| `-zebrastart 0\|1` | 0 | Zebra phase offset (used for row ranges) |
| `-fontsize <N>` | 9 | Font size in points |
| `-pad <N>` | 4 | Cell padding in points |
| `-border 0\|1` | 1 | Grid lines |
| `-rowheight <pt>` | 0 | 0 = `1.8 * fontsize` |
| `-cellstyles {R,C {…} …}` | — | Per-cell style: `-bg {r g b} -fg {r g b} -font bold -align right` |
| `-rowstyles {R {…} …}` | — | Per-row style: `-bg -fg -font` |
| `-rowindent {R <pt> …}` | — | Indent the first column of a row (tree mode) |
| `-footer {values…}` | — | Bold summary row (heavier separator line) |
| `-footerbg {r g b}` | light gray | Footer background |
| `-footerbold 0\|1` | 1 | Footer in bold |
| `-yvar <name>` | — | Write back the next Y position |
| `-pagevar <name>` | — | Read/write the page counter (with `-ctx`) |
| `-orient 0\|1` | 1 | For the internal page break |
| `-pagebreakcmd <cmd>` | — | Custom page-break callback (as in `table::render`) |

**Style precedence:** cell > row > zebra.

The line weights and text baseline reproduce the `pdf4tcltable 0.2` look, so
the widget adapter stays visually compatible.

---

## Example

```tcl
package require pdf4tcl
package require pdf4tcllib
::pdf4tcllib::fonts::init -cid 1     ;# full Unicode (€ etc.); else WinAnsi

set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
$pdf startPage
set y [dict get $ctx top]

set cols {
    {-header "Item"    -width auto}
    {-header "No."     -width 90}
    {-header "Price €" -width 70 -align right}
}
set data {
    {"Laptop 15" "E-001" "899.00"}
    {"Laptop 13" "E-002" "749.00"}
    {"Chair"     "B-001" "129.00"}
}

set y [pdf4tcllib::table::draw $pdf [dict get $ctx left] $y $cols $data \
    -ctx        $ctx \
    -zebra      1 \
    -cellstyles {0,2 {-fg {0.8 0 0} -font bold}} \
    -footer     {"Total" "" "1,777.00"} \
    -yvar       y]

$pdf endPage
$pdf write -file out.pdf
$pdf destroy
```

### Tree indentation + footer

```tcl
set cols {{-header "Category / Item" -width auto}
          {-header "No." -width 90}
          {-header "Price" -width 70 -align right}}
set data {
    {"Electronics" "" ""}
    {"Laptop 15" "E-001" "899.00"}
    {"Laptop 13" "E-002" "749.00"}
}
pdf4tcllib::table::draw $pdf $x $y $cols $data \
    -rowstyles {0 {-font bold}} \
    -rowindent {1 14  2 14} \
    -footer    {"Total" "" "1,648.00"}
```

`-rowindent` shifts the first column right; `-width auto` accounts for the
indent so indented cells are not truncated.

---

## Unicode

`table::draw` draws via `pdf4tcllib::unicode::safeText`. With TTF fonts loaded
(`pdf4tcllib::fonts::init -cid 1`, DejaVu) the €, arrows, CJK etc. render
correctly; without TTF it falls back to WinAnsi/Latin-1 (`sanitize` replaces
what does not fit).

## Page breaks

With `-ctx`, `draw` starts a new page as soon as the next row would cross
`[dict get $ctx bottom]`, and repeats the header. `-pagevar` yields the page
count. Without `-ctx` everything is drawn on the current page (no break).

## Column widths

`-width auto` measures the content width (bold header, regular cells,
including `-rowindent`). Fixed point widths are used as given; if their sum
exceeds `-maxwidth` they are scaled down proportionally.

---

## Relationship to the other table APIs

| API | Purpose |
|-----|---------|
| `table::draw` | **data-driven, Tk-free**; styling / page breaks / footer / indent |
| `table::render` | older low-level renderer (list/dict, many positional args) |
| `table::simpleTable` | simple table with fixed point widths, few options |
| `tablelist::render` (pdf4tcltable) | **Tk widget** → PDF; adapter over `table::draw` since 0.3 |
