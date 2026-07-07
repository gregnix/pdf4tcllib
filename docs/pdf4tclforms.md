# pdf4tclforms — Declarative Fillable PDF Forms

**Package:** `pdf4tclforms 0.1.2`  
**File:** `pdf4tclforms-0.1.2.tm`  
**Requires:** `pdf4tcllib 0.3`, `pdf4tcl 0.9.4.33+` (needs `addForm` with `-format`; `-calculate` 0.9.4.32+, appearance 0.9.4.30+)

Renders complete fillable **AcroForm** documents from a single Tcl dict, or
from one of four built-in templates. Builds on the `pdf4tcllib::form`
primitives (section headers, labelled fields, rows, tables, sum lines) and adds
a declarative schema layer plus label/field layout.

Like `pdf4tcltext` / `pdf4tcltable`, this is an **optional** `.tm` module. It is
not loaded by `pdf4tcllib` itself.

> **Note:** AcroForm fields use Helvetica (WinAnsi). Only WinAnsi characters are
> reliable in form fields — no CID fonts. German umlauts work; characters above
> U+00FF do not.

---

## Installation

```tcl
tcl::tm::path add /path/to/lib
package require pdf4tclforms 0.1.2
```

`pdf4tclforms` automatically loads `pdf4tcllib 0.3`. Two namespaces become
available:

- `pdf4tclforms::` — the public alias namespace (recommended)
- `pdf4tcllib::forms::` — the same procs, fully qualified

The low-level primitives stay reachable under `pdf4tcllib::form::` (and are also
aliased into `pdf4tclforms::`, see [Low-level primitives](#low-level-primitives)).

---

## Quick Start

```tcl
package require pdf4tclforms 0.1.2
package require pdf4tcl

# A form context. -orient true: y grows downward (top-left origin).
set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set y [dict get $ctx top]

# 1) A built-in template
pdf4tclforms::renderSchema $pdf $ctx [pdf4tclforms::template callnote] -yvar y

# 2) ...or your own schema dict
#    pdf4tclforms::renderSchema $pdf $ctx $mySpec -yvar y

$pdf endPage
$pdf write -file callnote.pdf
$pdf destroy
```

Open the result in any PDF reader; the fields are fillable and saveable.

---

## Commands

All commands are available both as `pdf4tclforms::<cmd>` and
`pdf4tcllib::forms::<cmd>`.

### pdf4tclforms::template

```tcl
pdf4tclforms::template name ?-option value ...?
```

Returns a **schema dict** (does not draw anything). Pass the result to
`renderSchema`.

| Template | Content | Options |
|---|---|---|
| `callnote` | Phone call note | `-title` |
| `inventory` | PC inventory (3 sections) | `-title` |
| `checklist` | Editable list table | `-title -headers -widths -emptyRows` |
| `order` | Order form with position table | `-title -emptyRows` |

Unknown names raise an error.

### pdf4tclforms::renderSchema

```tcl
pdf4tclforms::renderSchema pdf ctx spec ?-yvar name? ?-pagebreak 0|1?
```

Draws a whole form from a schema dict. Returns the final `y`.

| Argument | Meaning |
|---|---|
| pdf | pdf4tcl object |
| ctx | page context from `pdf4tcllib::page::context` (use `-orient true`) |
| spec | schema dict (must contain a `sections` key) |
| -yvar | name of the caller's y variable to advance (default `y`) |
| -pagebreak | `1` to break to a new page when a field/table would overflow (default `0`) |

`spec` needs a `sections` key or `renderSchema` errors.

### pdf4tclforms::renderSection

```tcl
pdf4tclforms::renderSection pdf ctx yVar sdef ?pagebreak?
```

Draws a single section. `renderSchema` calls this per section. Order within a
section is fixed: **title → fields → table → sums** (regardless of dict order).

### pdf4tclforms::field / checkboxLine / entryTable

Building blocks used by `renderSection`; callable directly if you assemble a
form imperatively instead of from a spec.

```tcl
pdf4tclforms::field       pdf ctx yVar fdef ?pagebreak?
pdf4tclforms::checkboxLine pdf ctx yVar fdef ?pagebreak?
pdf4tclforms::entryTable  pdf ctx yVar tblSpec ?pagebreak?
```

- `field` — one labelled field (single-line: label left / field right;
  multiline: label above / field full width; `type checkbox` delegates to
  `checkboxLine`).
- `checkboxLine` — a checkbox with its label to the right.
- `entryTable` — a table; `editable 1` makes every cell a fillable field.

---

## Schema Structure

A schema is a plain dict. Nesting is expressed with `dict create`.

```tcl
dict create \
    title "Form Title" \
    sections [dict create \
        s1 [dict create \
            title  "Section heading" \
            fields { ... } \
            table  { ... } \
            sums   { ... }]]
```

### Top level

| Key | Required | Meaning |
|---|---|---|
| `title` | no | Document title (large, drawn once at the top) |
| `sections` | **yes** | dict of `sectionKey -> section` |

### Section

| Key | Meaning |
|---|---|
| `title` | Grey section header bar |
| `fields` | List of field entries (see below) |
| `table` | One `tblSpec` table (see [Editable tables](#editable-tables)) |
| `sums` | List of sum-line dicts (see [Sum lines](#sum-lines)) |

### Sum lines

Each entry in `sums` is a dict. By default the value is static text:

```tcl
{widths {25 200} label "Total:" value "42.00"}
```

It can instead be a **calculated field** that totals other fields live in a
JavaScript-capable viewer (needs pdf4tcl 0.9.4.32+):

| Key | Meaning |
|---|---|
| `widths` | Column widths; label/value sit in the last two columns |
| `label` | Right-aligned bold label |
| `value` | Static text (used only when no `id`/`calculate`/`over`) |
| `id` | Field id of the value cell → renders a right-aligned form field |
| `calculate` | `{op {f1 f2 …}}` (op: `sum`/`product`/`average`/`min`/`max`) |
| `over` | `{idPrefix col count ?start?}` — convenience: total an editable table column (cells `idPrefix_row_col`); auto-builds `calculate` and `id` |
| `init` | Static pre-value shown in non-JS viewers |
| `format` | Number formatting for the value field, e.g. `{number decimals 2 sep german currency " €"}` (pdf4tcl 0.9.4.33+) |
| `js` | Raw JavaScript actions `{event code …}` for the value field, e.g. VAT/total lines referencing another field (pdf4tcl 0.9.4.34+) |

`over` is the easy path for a positions table. Given a table with
`idPrefix f_pos` and 4 rows whose amount column is index 3:

```tcl
table [dict create headers {Pos Article Qty Amount} \
    widths {30 250 60 90} emptyRows 4 editable 1 idPrefix f_pos]
sums {
    {widths {30 250 60 90} label "Total:" over {f_pos 3 4} init "0"}
}
```

This sums cells `f_pos_0_3 … f_pos_3_3` live (via `AFSimple_Calculate`) and
shows `0` statically until edited. Without `id`/`calculate`/`over` the sum line
stays plain text — unchanged and viewer-independent.

### `fields` entries

`fields` is a **list**; each element is one of:

```tcl
fields {
    {id f_name type text label "Name:" required 1}          ;# a field
    {row {                                                   ;# fields side by side
        {id f_date type text label "Date:" width 120}
        {id f_time type text label "Time:" width 100}
    }}
    {separator 4}                                            ;# horizontal rule + gap
    {id f_note type text label "Note:" multiline 1 fieldh 80};# multiline field
    {id f_done type checkbox label "Done" init false}        ;# checkbox (label right)
    {table { headers {Nr Text} widths {30 200} emptyRows 5 editable 1 }}
    {sums { {widths {25 200} label "Total:" value ""} }}
}
```

Recognised special entries: `{row {...}}`, `{separator N}`, `{table {...}}`,
`{sums {...}}`. Anything else is treated as a single field dict.

---

## Field Options

A field dict mixes **layout keys** (consumed by pdf4tclforms) and **addForm
keys** (passed through to `pdf4tcl addForm`).

### Layout keys (not passed to addForm)

| Key | Meaning |
|---|---|
| `type` | Field type: `text`, `combobox`, `checkbox`, `password`, … |
| `label` | Label text |
| `labelw` | Label column width in pt (default from config, ~90) |
| `fieldh` | Field height in pt (default from config, 16) |
| `fieldw` | Explicit field width (default: fill the section width) |
| `width` | **Row only:** total width of the label+field pair |
| `gap` | **Row only:** gap between label and field |

### addForm keys (passed through, whitelisted)

`id`, `init`, `options`, `readonly`, `multiline`, `required`, `tooltip`,
`tabindex`.

Field appearance (requires pdf4tcl 0.9.4.30+ / 0.9.4.31+), for
`text`/`password`/`combobox`/`listbox` fields:

- `align` — value alignment `left` | `center` | `right` (pdf4tcl 0.9.4.30+)
- `color` — text color (pdf4tcl 0.9.4.31+)
- `borderwidth`, `bordercolor` — field border (pdf4tcl 0.9.4.31+)
- `bgcolor` — background fill (pdf4tcl 0.9.4.31+)
- `calculate` — `{op {f1 f2 …}}` live calculation (pdf4tcl 0.9.4.32+)
- `format` — number formatting, e.g. `{number decimals 2 sep german currency " €"}` (pdf4tcl 0.9.4.33+)
- `js` — raw JavaScript actions `{event code …}` (event: calculate/format/validate/keystroke), e.g. VAT `{calculate {event.value = this.getField("net").value * 1.19;}}` (pdf4tcl 0.9.4.34+)

These are passed to `addForm` for single fields (`field`), fields inside a
`row`, and editable table columns (via the table `columns` key). Colors are
pdf4tcl colors (RGB/CMYK list or `#rrggbb`; names need Tk).

Everything else (`label`, `labelw`, `fieldh`, `width`, …) is a layout key and is
**never** forwarded to `addForm` — labels are drawn as PDF text.

Boolean coercion is applied only where it belongs: `required` always, and `init`
only for `checkbox`/`checkbutton`. A `combobox` `init` such as `"Normal"` is kept
verbatim as a string.

### Type notes

- `checkbox` renders via `checkboxLine` (box + label to the right), never a
  label column.
- `multiline 1` puts the label on its own line above and the field at full width
  below, so a long label cannot run into the field box. Set `fieldh` to size the
  text area.
- `combobox` takes `options {..}`; the shown default is `init`.
- `required 1` adds a red `*` after the label.
- `radio` renders a group of radio buttons sharing one field. Keys: `label`,
  `group` (field name), `options {{value "Label"} …}`, optional `init value`
  (preselected). Buttons flow horizontally and wrap to the next line as needed.
- `buttons` renders a horizontal button bar. Key `items` is a list of button
  dicts `{id ID caption "Text" action submit|reset|url ?url "…"?}`. Useful for
  Submit/Reset at the end of a form.
- `combobox` / `listbox` extra keys: `editable 1` (combobox: free text entry),
  `multiselect 1` (listbox: multiple selection), `sort 1` (listbox: sorted).
  Set `fieldh` to give a listbox room for several rows.
- `signature` renders a signature field (label above, tall box below). Keys:
  `label` (caption), `placeholder` (text on the line), `fieldh` (box height,
  default 45), `readonly`.

---

## Rows

`{row { fieldA fieldB ... }}` places several label+field pairs on one line. Each
pair's `width` is the **total** for that pair; the label column sizes to the
label text (unless `labelw` is given), and the field takes the remainder.

```tcl
{row {
    {id f_zip  type text label "ZIP:"  width 90}
    {id f_city type text label "City:" width 210}
}}
```

Keep `width` comfortably larger than the label text plus a usable field, or the
field is clamped to a minimum width.

---

## Editable Tables

A `table` (in a section or as a `{table {...}}` field entry) is a `tblSpec`:

| Key | Meaning |
|---|---|
| `headers` | List of column headers |
| `widths` | List of column widths in pt |
| `rows` | Data rows (list of cell-lists), optional |
| `emptyRows` | Number of blank rows to append (default 0) |
| `editable` | `1` = every cell is a fillable text field; `0` = static text |
| `idPrefix` | Field-id prefix for editable cells (`prefix_row_col`) |
| `rowh` | Row height in pt |
| `headerBg` | Header background color `{r g b}` |
| `columns` | Per-column appearance for editable cells: `{colIdx {align … format … color …} …}`. Same appearance keys as fields (`align`/`color`/`border*`/`bgcolor`/`format`). E.g. a right-aligned, Euro-formatted amount column: `{3 {align right format {number decimals 2 sep german currency " €"}}}` |

```tcl
table [dict create \
    headers   {Pos Article Qty Price} \
    widths    {25 210 45 70} \
    emptyRows 6 \
    editable  1 \
    idPrefix  f_pos]
```

Under the hood, editable tables route through `pdf4tcllib::form::orderTable`
with its `-cellForm` option, so static and editable tables share one renderer.

---

## Page Breaks

By default a form is drawn on the current page and may overflow if it is longer
than the page. Pass `-pagebreak 1` to `renderSchema` to break to a fresh page
whenever a field, checkbox, or table would cross the bottom margin
(`dict get $ctx bottom`).

```tcl
pdf4tclforms::renderSchema $pdf $ctx $longSpec -yvar y -pagebreak 1
```

---

## Coordinate Context

`renderSchema` and the field procs read the page context produced by
`pdf4tcllib::page::context`:

| Key | Meaning |
|---|---|
| `SX` | Left x of the content area |
| `SW` | Content width |
| `top` | Starting y |
| `bottom` | y of the bottom margin (used by `-pagebreak`) |

Create the context and the pdf object both with `-orient true` so y grows
downward:

```tcl
set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
```

---

## Low-level Primitives

The `pdf4tcllib::form::` procs are exported and also aliased into
`pdf4tclforms::`. Use them to build a form imperatively:

```tcl
pdf4tclforms::section    $pdf $ctx y "Customer"
pdf4tclforms::labelField $pdf $ctx y "Name:"  text -id f_name
pdf4tclforms::row        $pdf $ctx y {
    {label "ZIP:"  type text width  90 id f_zip}
    {label "City:" type text width 210 id f_city}
}
pdf4tclforms::separator  $pdf $ctx y
pdf4tclforms::orderTable $pdf $ctx y \
    {"Pos" "Item" "Qty" "Price"} {25 210 45 70} {} -emptyRows 5 -cellForm f_pos
pdf4tclforms::sumLine    $pdf $ctx y {25 210 45 70} "Total:" ""
```

Aliased primitives: `configure`, `section`, `labelField`, `row`, `separator`,
`orderTable`, `sumLine`, `fieldHeight`, `rowHeight`. Global look (fonts, colors,
spacing, default label width and field height) is set with
`pdf4tclforms::configure` — see `docs/API.md` (form namespace).

---

## Fonts and Limitations

- AcroForm field text uses Helvetica (WinAnsi). No CID fonts in form fields.
- Characters above U+00FF are not reliable in fields; German umlauts are fine.
- Field ids must be unique within the document. Editable-table cells are named
  `idPrefix_row_col`; pick a distinct `idPrefix` per table.

---

## Common Mistakes

- **Context without `-orient true`.** Fields land with the origin at the wrong
  corner. Create both `page::context` and the pdf object with `-orient true`.
- **`spec` without `sections`.** `renderSchema` errors: it needs a `sections`
  key even for a one-section form.
- **`fields` as a dict instead of a list.** `fields` is an ordered **list** of
  entries; each entry is itself a dict (or a `row`/`separator`/`table`/`sums`
  marker).
- **Row `width` too small.** In a `row`, `width` is the *total* pair width. If it
  barely exceeds the label, the field is clamped to a minimum. Give each pair
  room.
- **Passing layout keys to `addForm` yourself.** When calling `addForm`
  directly, do not pass `label`/`labelw`/`fieldh`/`width` — those are not
  `addForm` options. `pdf4tclforms` strips them via a whitelist.
- **Reusing a field id.** Duplicate ids collapse into one AcroForm field.

---

## Checklist

- [ ] `package require pdf4tclforms 0.1.2`
- [ ] `page::context` and pdf object both `-orient true`
- [ ] `spec` has a `sections` key
- [ ] `fields` is a list; special entries are `row` / `separator` / `table` / `sums`
- [ ] editable tables have a unique `idPrefix`
- [ ] long forms use `-pagebreak 1`
- [ ] only WinAnsi characters in field values
