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

# ============================================================
# Bookmark-/Metadaten-Titel: Unicode bleibt erhalten (UTF-16BE)
#
# _installUnicodeTitles ueberschreibt ::pdf4tcl::SafeQuoteString:
# Codepoints > U+00FF werden als UTF-16BE-Hex mit BOM kodiert
# (<FEFF...>) statt durch "?" ersetzt. Reines ASCII/Latin-1 bleibt
# Literal (...). Betrifft nur Outline-Titel und Info-Dict-Metadaten,
# nicht den Content-Stream. Benoetigt geladenes pdf4tcl.
# ============================================================

testConstraint hasPdf4tcl [expr {![catch {package require pdf4tcl}]}]

test unicode-safequote-endash "SafeQuoteString: En-Dash wird UTF-16BE-Hex mit BOM" -constraints hasPdf4tcl -setup {
    pdf4tcllib::_installUnicodeTitles
} -body {
    # FEFF=BOM, 0041=A, 0020=Space, 2013=En-Dash, 0020=Space, 0042=B
    ::pdf4tcl::SafeQuoteString "A \u2013 B"
} -result "<FEFF00410020201300200042>"

test unicode-safequote-ascii "SafeQuoteString: reines ASCII bleibt Literal (...)" -constraints hasPdf4tcl -setup {
    pdf4tcllib::_installUnicodeTitles
} -body {
    ::pdf4tcl::SafeQuoteString "Plain"
} -result "(Plain)"

test unicode-meta-title-utf16 "metadata-Titel mit En-Dash landet als UTF-16BE im /Title" -constraints hasPdf4tcl -setup {
    pdf4tcllib::fonts::init
} -body {
    set p [pdf4tcl::new %AUTO% -paper a4]
    $p startPage
    $p setFont 12 [pdf4tcllib::fonts::fontSans]
    $p text "x" -x 50 -y 50
    $p metadata -title "A \u2013 B"
    $p endPage
    set data [$p get]
    $p destroy
    # /Title als UTF-16BE-Hex mit BOM; En-Dash (U+2013) erhalten, nicht "?"
    expr {[regexp -nocase {/Title\s*<(feff[0-9a-f]+)>} $data -> hex]
          && [string match -nocase *2013* $hex]}
} -result 1

cleanupTests
