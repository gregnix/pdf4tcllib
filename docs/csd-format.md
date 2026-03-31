# Cheatsheet Data Format (.csd)

**Package:** `cheatsheet 0.1`  
**File:** `cheatsheet-0.1.tm`

A `.csd` file (Cheatsheet Data) contains a single Tcl dict that describes
the content of one cheat sheet page. Layout, colors, and rendering are
handled entirely by the `cheatsheet` package — the `.csd` file contains
only data.

---

## File Structure

A `.csd` file contains a plain Tcl dict with three keys:

```
title    "Title text shown in the page header"
subtitle "Subtitle shown below the title"
sections {
    { ...section... }
    { ...section... }
    ...
}
```

No `package require`, no `set`, no procedure calls. The file is read
by `cheatsheet::fromDict` via `read` and used directly as a dict value.

---

## Loading

```tcl
package require cheatsheet 0.1

# Single sheet -> one PDF
cheatsheet::fromDict output.pdf [cheatsheet::loadCsd data/mysheet.csd]

# Or read manually
proc loadCsd {path} {
    set f [open $path]
    set d [read $f]
    close $f
    return [string trim $d]
}
cheatsheet::fromDict output.pdf [loadCsd data/mysheet.csd]
```

---

## Section Format

Each section is a Tcl dict with three required keys:

```
{
    title   "Section heading"
    type    table|code|hint|list
    content { ...rows... }
}
```

An optional `mono` key sets the default monospace flag for all rows
in a `table` section:

```
{title "Commands" type table mono 1 content { ... }}
```

---

## Section Types

### type table

Two-column layout: label (bold, grey) on the left, value on the right.

Each content row is a Tcl list with 2 or 3 elements:

```
{ label  {value text}  ?mono? }
```

| Field | Description |
|-------|-------------|
| `label` | Short identifier shown in bold. Must be a single Tcl word — use `{braces}` if the label contains spaces. |
| `{value text}` | Description or code snippet. Always brace-quoted. |
| `mono` | Optional. `1` = Courier font for the value, `0` = Helvetica (default). |

```
sections {
    {title "Text" type table content {
        {setFont        {$pdf setFont 12 Helvetica}     1}
        {text           {$pdf text "Hi" -x 50 -y 100}  1}
        {Fonts          {Helvetica Times-Roman Courier} 0}
        {{orient true}  {y=0 top, grows downward}      0}
    }}
}
```

> **Important:** Labels containing spaces must be wrapped in an extra
> pair of braces: `{{label with spaces}  {value}  0}`.
> Without braces, Tcl parses the label words as separate list elements,
> causing a "missing value to go with key" error.

### type code

Monospace code block. Each content item is one line of code:

```
{title "Setup" type code content {
    {lappend auto_path /path/to/lib}
    {package require pdf4tcl 0.9.4.25}
    {set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]}
    {$pdf startPage}
    {$pdf endPage}
    {$pdf write -file out.pdf}
    {$pdf destroy}
}}
```

Lines are rendered in Courier 7pt. Column and page breaks are applied
automatically between sections, not within a section.

### type hint

Single highlighted note with a yellow-grey background. Each content item
is one line of hint text:

```
{title "Note" type hint content {
    "Always set -orient true explicitly."
    "Call update idletasks before canvas export."
}}
```

### type list

Indented list with `- ` prefix per item:

```
{title "Requirements" type list content {
    "Tcl/Tk 8.6 or 9.0"
    "pdf4tcl 0.9.4.25+"
    "optional: tablelist_tile"
}}
```

---

## Layout

The page is divided into two columns. Sections flow left-to-right,
top-to-bottom. Column and page breaks are inserted automatically when
`y_max` is exceeded.

Layout constants can be adjusted with `cheatsheet::setStyle`:

| Key | Default | Description |
|-----|---------|-------------|
| `col1_x` | 8 | Left column X position (pt) |
| `col2_x` | 302 | Right column X position (pt) |
| `col_w` | 284 | Column width (pt) |
| `val_off` | 85 | Value offset within column (pt) |
| `y_start` | 50 | Y after page header |
| `y_max` | 650 | Y threshold for column/page break |
| `row_h` | 12 | Minimum row height (pt) |
| `code_h` | 10 | Code line height (pt) |
| `sec_h` | 20 | Section header height (pt) |
| `sep_h` | 8 | Separator height (pt) |

```tcl
# Example: wider value column
cheatsheet::setStyle val_off 70 col_w 290
cheatsheet::fromDict output.pdf [loadCsd data/mysheet.csd]
# Reset is not automatic -- restart interpreter or set back manually
```

---

## Public API

```tcl
cheatsheet::fromDict  outfile data      ;# dict -> one PDF file
cheatsheet::fromDicts outfile datalist  ;# list of dicts -> one PDF (multiple pages)
cheatsheet::render    pdf data          ;# render into existing pdf4tcl object
cheatsheet::getStyle                    ;# returns current layout as dict
cheatsheet::setStyle  key val ...       ;# override layout constants
```

---

## Directory Layout

```
app/
  make_cheatsheets        main runner script
  csdata/
    pdf4tcl.csd           sheet data: pdf4tcl API
    pdf.csd               sheet data: PDF fundamentals
    canvas.csd            sheet data: canvas export
    pdf-internals.csd     sheet data: PDF internals
out/                      generated PDFs (created automatically)
```

---

## Complete Minimal Example

```
# mysheet.csd
title    "My Cheat Sheet"
subtitle "A quick reference"
sections {
    {title "Setup" type code content {
        {package require mylib 1.0}
        {mylib::init}
    }}
    {title "Commands" type table content {
        {open    {mylib::open filename}   1}
        {read    {mylib::read $handle}    1}
        {close   {mylib::close $handle}  1}
    }}
    {title "Note" type hint content {
        "Always close handles after use."
    }}
}
```

```tcl
package require cheatsheet 0.1
cheatsheet::fromDict out/mysheet.pdf [loadCsd csdata/mysheet.csd]
```

---

## Common Mistakes

**"missing value to go with key"**  
Label contains a space but is not braced:
```
# WRONG
{my label  {value}  0}

# CORRECT
{{my label}  {value}  0}
```

**Outer braces in .csd file**  
The file must not start with `{` and end with `}` — the dict content
is written directly without enclosing braces. `loadCsd` passes the
raw file content to `dict get`; an extra brace layer creates a single
opaque string instead of a dict.

```
# WRONG (file starts with {)
{
    title "My Sheet"
    ...
}

# CORRECT (content directly at top level)
title    "My Sheet"
subtitle "..."
sections {
    ...
}
```

**Code line with unbalanced braces**  
Code lines are brace-quoted list elements. A lone `}` or `{` inside a
code line must be escaped:
```
# WRONG -- unbalanced brace breaks the list
{set x [expr {$a + $b}]}

# CORRECT -- escape the inner closing brace
{set x [expr \{$a + $b\}]}
# or rewrite without braces
{set x [expr $a+$b]}
```
