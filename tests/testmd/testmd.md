# Markdown Rendering Test

This document tests Markdown rendering and PDF generation in mdhelp.

---

# 1 Headings

## Level 2 Heading

### Level 3 Heading

#### Level 4 Heading

---

# 2 Paragraphs

This is a normal paragraph used to test line wrapping and paragraph spacing.

This is another paragraph to verify spacing between paragraphs.

This paragraph contains **bold text**, *italic text*, and **bold with *italic* inside**.

---

# 3 Inline Code

Example of inline code:

Use the command `package require tablelist_tile`.

Another example:

`dict get $item name`

---

# 4 Code Blocks

Example Tcl code:

```
proc hello {} {
    puts "Hello World"
}
```

More complex example:

```
try {
    set data [read $fd]
} on error {msg opts} {
    log::error $msg
    return -options $opts $msg
} finally {
    close $fd
}
```

---

# 5 Lists

## Unordered List

* first item
* second item
* third item

Nested list:

* item

  * sub item
  * sub item
* item

## Ordered List

1. first
2. second
3. third

---

# 6 Tables

| Name  | Age | City    |
| ----- | --- | ------- |
| Alice | 30  | Berlin  |
| Bob   | 41  | Hamburg |
| Carol | 25  | Munich  |

---

# 7 Blockquotes

> This is a blockquote.
>
> It should be indented and visually separated from normal text.

---

# 8 Horizontal Rules

Below this line should be a horizontal rule.

---

Text continues after the rule.

---

# 9 Tree Structures

Filesystem tree example:

```
project/
├─ app/
│  └─ main.tcl
├─ src/
│  ├─ model/
│  ├─ actions/
│  └─ ui/
└─ lib/
```

---

# 10 Long Text

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed non risus. Suspendisse lectus tortor, dignissim sit amet, adipiscing nec, ultricies sed, dolor.

Cras elementum ultrices diam. Maecenas ligula massa, varius a, semper congue, euismod non, mi.

---

# 11 Mixed Formatting

This line contains **bold**, *italic*, `inline code`, and a link:

https://example.com

---

# 12 Special Characters

Characters to test UTF-8 handling:

ä ö ü ß
Ä Ö Ü
€ £ ¥

---

# 13 Large Code Block

```
namespace eval ::app::model {

    proc newItem {} {
        return [dict create id "" name "" created ""]
    }

    proc validateItem {item} {

        if {[dict get $item name] eq ""} {
            error "Name required"
        }

        return $item
    }

}
```

---

# 14 Copy Paste Test

The following text must be selectable in the PDF.

Example command:

```
tclsh main.tcl --test
```

---

# 15 Page Break Test

Content before page break.

Content after page break.

---

# End of Document
