# test_subst_cid.tcl -- sanitize im CID-Modus (0.6.6)
# Nicht-ASCII nur als \uXXXX: Tcl 8.6 liest die Datei sonst in der
# Systemkodierung (cp1252 unter Windows, ASCII unter LANG=C).
#
# Bis 0.6.5 ging im CID-Modus jedes Zeichen durch. Fehlte es im Font,
# zeichnete pdf4tcl ein leeres .notdef-Kaestchen, ohne Zaehler, ohne Wort.
# Gemessen 19.10.2026 an einem Buchbau: eine japanische Beispielzeile kam
# als Kaestchenreihe heraus, ein Tab in einem Makefile-Codeblock als
# Kaestchen, und -mono machte aus U+2318 ein "?", obwohl DejaVu Sans Mono es hat.
#
# Seit 0.6.6:
#   - fehlende Glyphe -> "?", gezaehlt
#   - geprueft wird der Font, der zeichnet (-mono: Mono, sonst Regular)
#   - -mono behaelt Unicode, wenn der Mono-Font ein TTF ist
#   - Tabs werden zu Leerzeichen (-tabwidth, Standard 4)

package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file join [file dirname [file normalize [info script]]] .. lib]

testConstraint pdf [expr {![catch {package require pdf4tcl}]}]
testConstraint lib [expr {![catch {package require pdf4tcllib}]}]
# DejaVu im CID-Modus; ohne TTF gibt es nichts zu pruefen.
testConstraint cid [expr {[testConstraint lib] && [testConstraint pdf] &&
    ![catch {::pdf4tcllib::fonts::init -cid 1}] &&
    [::pdf4tcllib::fonts::hasTtf] && [::pdf4tcllib::fonts::isCidMode]}]
testConstraint monoTtf [expr {[testConstraint cid] &&
    [::pdf4tcllib::fonts::fontMono] eq "Pdf4tclMono"}]

proc sz {txt args} {
    ::pdf4tcllib::unicode::resetSubst
    set r [::pdf4tcllib::unicode::sanitize $txt {*}$args]
    list $r [::pdf4tcllib::unicode::substCount]
}

test subst-cid-1.1 {Kana fehlen in DejaVu: sichtbar und gezaehlt} \
        -constraints cid -body {
    sz "%s \u3092\u30D5\u30A1"
} -result {{%s ???} 3}

test subst-cid-1.2 {Text: U+2318 und Umlaute gehen durch} -constraints cid -body {
    sz "\u2318C kopiert, Gr\u00F6\u00DFe 5 \u20AC"
} -result [list "\u2318C kopiert, Gr\u00F6\u00DFe 5 \u20AC" 0]

test subst-cid-2.1 {Code: U+2318, U+2192, U+2202 bleiben im Mono-TTF} -constraints monoTtf \
        -body {
    sz ";# \u2318C \u2192 \u2202" -mono 1
} -result [list ";# \u2318C \u2192 \u2202" 0]

test subst-cid-2.2 {Code: nur in Sans (U+01C4) wird "?"} -constraints monoTtf \
        -body {
    # Gegen den Regular-Font geprueft ginge es durch und verschwaende.
    sz "\u01C4" -mono 1
} -result {? 1}

test subst-cid-2.3 {Code: nur in Mono (U+238B) bleibt} -constraints monoTtf \
        -body {
    # Gegen den Regular-Font geprueft wuerde es faelschlich "?".
    sz "\u238B" -mono 1
} -result [list "\u238B" 0]

test subst-cid-2.4 {Text: nur in Sans (U+01C4) bleibt} -constraints cid -body {
    sz "\u01C4"
} -result [list "\u01C4" 0]

test subst-cid-3.1 {Tab am Zeilenanfang} -constraints cid -body {
    lindex [sz "\ttclsh run.tcl" -mono 1] 0
} -result {    tclsh run.tcl}

test subst-cid-3.2 {Tab mitten in der Zeile: bis zur naechsten Spalte} \
        -constraints cid -body {
    lindex [sz "ab\tc" -mono 1] 0
} -result {ab  c}

test subst-cid-3.3 {Tab je Zeile neu gezaehlt} -constraints cid -body {
    lindex [sz "a\tb\n\tc"] 0
} -result "a   b\n    c"

test subst-cid-3.4 {-tabwidth 8} -constraints cid -body {
    lindex [sz "\tx" -mono 1 -tabwidth 8] 0
} -result {        x}

test subst-cid-4.1 {im PDF: kein Tab, keine Kana im Inhaltsstrom} \
        -constraints cid -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    $pdf setFont 11 [::pdf4tcllib::fonts::fontMono]
    ::pdf4tcllib::unicode::resetSubst
    ::pdf4tcllib::unicode::safeText $pdf "\tmake \u3092" -x 40 -y 60 -mono 1
    set n [::pdf4tcllib::unicode::substCount]
    $pdf destroy
    set n
} -result 1

rename sz {}

cleanupTests
