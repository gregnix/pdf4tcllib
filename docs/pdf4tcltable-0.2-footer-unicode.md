# pdf4tcltable 0.2 — Footer & Unicode (Supplement)

New in `pdf4tcltable 0.2`. Fold these sections into `docs/pdf4tcltable.md`; the
existing `render` / `renderRange` documentation stays valid (all additions are
backward-compatible — defaults reproduce the 0.1 behaviour).

**Package:** `pdf4tcltable 0.2` · **File:** `pdf4tcltable-0.2.tm`

---

## Footer row

`render` can draw a footer row after the body, separated by a heavier line and
enclosed by the table border. The footer is bold by default and indexed by real
column number, like the body rows.

### Options

| Option         | Default | Meaning                                                        |
|----------------|---------|----------------------------------------------------------------|
| `-footer`      | `{}`    | A footer `tablelist` widget **or** an explicit list of values. |
| `-footerbg`    | `{}`    | Footer background `{r g b}` (0–1). Default light grey.          |
| `-footerbold`  | `1`     | Render the footer in the bold face.                            |

`-footer` is auto-detected: if it is a single existing widget that answers
`$w size`, row 0 of that widget is read (and its row background is used unless
`-footerbg` is given); otherwise the value is taken as an explicit cell list.

### Footer from a value list

```tcl
::pdf4tcllib::tablelist::render $pdf .tbl $x $y \
    -maxwidth 320 -footer {Sum 27 "7,70 €"}
```

### Footer from a tkutlfooter widget

```tcl
package require tkutils::tkutlfooter
::tkutils::tkutlfooter::attach  .tbl .foot
::tkutils::tkutlfooter::autosum .tbl .foot -columns {2} -label "Sum"

::pdf4tcllib::tablelist::render $pdf .tbl $x $y \
    -maxwidth 320 -footer .foot
```

> `renderRange` (paginated output) does not draw a footer — it renders a row
> range only. Draw the footer with `render`, or on the last page.

---

## Unicode fonts

In 0.1 the table was drawn with the Helvetica base-14 font, which covers only
ASCII/Latin-1. 0.2 uses the TTF sans faces of `pdf4tcllib::fonts`
(`fontSans` / `fontSansBold` / `fontSansItalic` / `fontSansBoldItalic`) when
they are loaded, so Greek, mathematical symbols, the `€` sign, CJK etc. render
correctly. Without TTF fonts it transparently falls back to Helvetica/Courier.

### Enabling Unicode

Initialise the fonts with CID encoding before rendering:

```tcl
::pdf4tcllib::fonts::init -fontdir /usr/share/fonts/truetype/dejavu -cid 1
```

After that, table cells, headers and footer render full Unicode automatically —
no per-call option needed.

### Font override options

| Option       | Default | Meaning                                            |
|--------------|---------|----------------------------------------------------|
| `-font`      | `{}`    | Override the regular face (else resolved as above).|
| `-boldfont`  | `{}`    | Override the bold face (header/footer/bold cells).  |

Per-row and per-cell `-font` settings from the widget are still honoured and
mapped to the matching regular/bold/italic/mono face of the resolved font set.

```tcl
::pdf4tcllib::tablelist::render $pdf .tbl $x $y \
    -font [::pdf4tcllib::fonts::fontSans] \
    -boldfont [::pdf4tcllib::fonts::fontSansBold]
```

---

## Compatibility

- Without `-footer`: identical output to 0.1.
- Without TTF fonts initialised: Helvetica base-14 as before (Latin-1 only).
- `pdf4tcllib/lib` is pure `tcl::tm`: drop `pdf4tcltable-0.2.tm` in and remove
  `pdf4tcltable-0.1.tm`.
