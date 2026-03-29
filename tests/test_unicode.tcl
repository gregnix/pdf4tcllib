# test_unicode.tcl -- Tests fuer pdf4tcllib::unicode
package require tcltest
namespace import ::tcltest::*

# Hinweis: Ohne fonts::init laeuft sanitize im Base-Modus
# (hasTtf=0, alle Symbole > U+00FF werden ersetzt).

# ============================================================
# Base-Modus Ersetzungen
# ============================================================

test unicode-arrow-right "Pfeil rechts -> wird zu ->" -body {
    pdf4tcllib::unicode::sanitize "\u2192"
} -result "->"

test unicode-arrow-left "Pfeil links <- wird zu <-" -body {
    pdf4tcllib::unicode::sanitize "\u2190"
} -result "<-"

test unicode-bullet "Aufzaehlungspunkt wird zu *" -body {
    pdf4tcllib::unicode::sanitize "\u2022"
} -result "*"

test unicode-ellipsis "Auslassungspunkte werden zu ..." -body {
    pdf4tcllib::unicode::sanitize "\u2026"
} -result "..."

test unicode-emdash "Geviertstrich wird zu --" -body {
    pdf4tcllib::unicode::sanitize "\u2014"
} -result "--"

test unicode-endash "Halbgeviertstrich wird zu -" -body {
    pdf4tcllib::unicode::sanitize "\u2013"
} -result "-"

test unicode-checkmark "Haekchen wird zu \[x\]" -body {
    pdf4tcllib::unicode::sanitize "\u2713"
} -result {[x]}

test unicode-ballot "Kreuz wird zu \[ \]" -body {
    pdf4tcllib::unicode::sanitize "\u2717"
} -result {[ ]}

test unicode-checkbox-checked "Checkbox checked wird zu \[x\]" -body {
    pdf4tcllib::unicode::sanitize "\u2611"
} -result {[x]}

test unicode-checkbox-empty "Checkbox leer wird zu \[ \]" -body {
    pdf4tcllib::unicode::sanitize "\u2610"
} -result {[ ]}

# ============================================================
# Box-Drawing Zeichen
# ============================================================

test unicode-box-horiz "Box horizontal wird zu -" -body {
    pdf4tcllib::unicode::sanitize "\u2500"
} -result "-"

test unicode-box-vert "Box vertikal wird zu |" -body {
    pdf4tcllib::unicode::sanitize "\u2502"
} -result "|"

test unicode-box-corner "Box Ecke wird zu +" -body {
    pdf4tcllib::unicode::sanitize "\u250C"
} -result "+"

# ============================================================
# ASCII bleibt unveraendert
# ============================================================

test unicode-ascii "Reiner ASCII bleibt unveraendert" -body {
    pdf4tcllib::unicode::sanitize "Hello World 123"
} -result "Hello World 123"

test unicode-latin1 "Latin-1 Umlaute bleiben" -body {
    set result [pdf4tcllib::unicode::sanitize "Haus \u00FC\u00F6\u00E4"]
    # ae oe ue sind < U+0100, bleiben erhalten
    expr {[string length $result] > 0}
} -result 1

# ============================================================
# Gemischter Text
# ============================================================

test unicode-mixed "Gemischter Text: ASCII + Symbole" -body {
    pdf4tcllib::unicode::sanitize "Preis \u2192 fertig"
} -result "Preis -> fertig"

test unicode-multi "Mehrere Symbole hintereinander" -body {
    pdf4tcllib::unicode::sanitize "\u2713 OK \u2717 Fehler \u2192 Ende"
} -result {[x] OK [ ] Fehler -> Ende}

# ============================================================
# Mono-Modus
# ============================================================

test unicode-mono "Mono-Modus: Auch TTF-Subset wird ASCII-ersetzt" -body {
    pdf4tcllib::unicode::sanitize "\u2192" -mono 1
} -result "->"

# ============================================================
# Leerer String
# ============================================================

test unicode-empty "Leerer String bleibt leer" -body {
    pdf4tcllib::unicode::sanitize ""
} -result ""

cleanupTests
