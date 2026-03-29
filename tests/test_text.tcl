# test_text.tcl -- Tests fuer pdf4tcllib::text
package require tcltest
namespace import ::tcltest::*

# ============================================================
# text::width -- Breitenberechnung
# ============================================================

test text-width-mono-1 "Courier: Jedes Zeichen gleich breit" -body {
    set w1 [pdf4tcllib::text::width "iii" 10 Courier]
    set w2 [pdf4tcllib::text::width "MMM" 10 Courier]
    # Bei Monospace muss Breite gleich sein
    expr {$w1 == $w2}
} -result 1

test text-width-mono-2 "Courier: 10 Zeichen bei 10pt = 10 * 10 * 0.60 = 60" -body {
    pdf4tcllib::text::width "0123456789" 10 Courier
} -result 60.0

test text-width-prop-1 "Helvetica: schmale Zeichen < breite Zeichen" -body {
    set w_narrow [pdf4tcllib::text::width "iii" 10 Helvetica]
    set w_wide   [pdf4tcllib::text::width "MMM" 10 Helvetica]
    expr {$w_narrow < $w_wide}
} -result 1

test text-width-prop-2 "Helvetica: 'i' ist schmal (0.55x)" -body {
    # 3 * 0.55 * 10 * 0.58 = 9.57
    format "%.2f" [pdf4tcllib::text::width "iii" 10 Helvetica]
} -result "9.57"

test text-width-prop-3 "Helvetica: 'M' ist breit (1.45x)" -body {
    # 3 * 1.45 * 10 * 0.58 = 25.23
    format "%.2f" [pdf4tcllib::text::width "MMM" 10 Helvetica]
} -result "25.23"

test text-width-empty "Leerer String = 0" -body {
    pdf4tcllib::text::width "" 10 Helvetica
} -result 0.0

test text-width-fontsize "Doppelte Fontgroesse = doppelte Breite" -body {
    set w10 [pdf4tcllib::text::width "Test" 10 Courier]
    set w20 [pdf4tcllib::text::width "Test" 20 Courier]
    format "%.1f" [expr {$w20 / $w10}]
} -result "2.0"

# ============================================================
# text::wrap -- Zeilenumbruch
# ============================================================

test text-wrap-fits "Kurzer Text passt: Eine Zeile" -body {
    llength [pdf4tcllib::text::wrap "Hello" 500 11 Helvetica]
} -result 1

test text-wrap-long "Langer Text wird umgebrochen" -body {
    set text "Dies ist ein langer Text der auf jeden Fall umgebrochen werden muss weil er breiter als die verfuegbare Breite ist"
    set lines [pdf4tcllib::text::wrap $text 200 11 Helvetica]
    expr {[llength $lines] > 1}
} -result 1

test text-wrap-content "Umgebrochene Zeilen enthalten alle Woerter" -body {
    set text "Eins Zwei Drei Vier"
    set lines [pdf4tcllib::text::wrap $text 80 11 Helvetica]
    set joined [join $lines " "]
    expr {$joined eq $text}
} -result 1

test text-wrap-single-word "Einzelnes langes Wort wird abgeschnitten" -body {
    set text "Donaudampfschifffahrtsgesellschaftskapitaen"
    set lines [pdf4tcllib::text::wrap $text 50 11 Helvetica]
    # Muss mindestens eine Zeile liefern (kein leeres Ergebnis)
    expr {[llength $lines] >= 1}
} -result 1

test text-wrap-code-continuation "Code-Continuation haengt \\ an" -body {
    set text "proc very_long_function_name {arg1 arg2 arg3 arg4 arg5 arg6}"
    set lines [pdf4tcllib::text::wrap $text 200 11 Courier 1]
    if {[llength $lines] > 1} {
        # Erste Zeile muss mit " \" enden
        expr {[string index [lindex $lines 0] end] eq "\\"}
    } else {
        # Passt in eine Zeile, OK
        expr {1}
    }
} -result 1

test text-wrap-code-cont-last "Letzte Zeile ohne Backslash" -body {
    set text "proc very_long_function_name {arg1 arg2 arg3 arg4 arg5 arg6}"
    set lines [pdf4tcllib::text::wrap $text 200 11 Courier 1]
    set last [lindex $lines end]
    # Letzte Zeile darf NICHT mit " \" enden
    expr {[string index $last end] ne "\\"}
} -result 1

test text-wrap-empty "Leerer String -> leere Liste oder ein Leerstring" -body {
    set lines [pdf4tcllib::text::wrap "" 500 11 Helvetica]
    # Muss eine Liste sein
    expr {[llength $lines] <= 1}
} -result 1

# ============================================================
# text::truncate -- Abschneiden
# ============================================================

test text-trunc-fits "Kurzer Text bleibt unveraendert" -body {
    pdf4tcllib::text::truncate "Hallo" 500 11 Helvetica
} -result "Hallo"

test text-trunc-long "Langer Text wird mit ... abgeschnitten" -body {
    set result [pdf4tcllib::text::truncate \
        "Donaudampfschifffahrtsgesellschaftskapitaen" 100 11 Helvetica]
    string match "*..." $result
} -result 1

test text-trunc-shorter "Abgeschnittener Text ist kuerzer als Original" -body {
    set orig "Dies ist ein langer Text der abgeschnitten werden muss"
    set result [pdf4tcllib::text::truncate $orig 100 11 Helvetica]
    expr {[string length $result] < [string length $orig]}
} -result 1

# ============================================================
# text::expandTabs -- Tab-Expandierung
# ============================================================

test text-tabs-basic "Tab wird zu Leerzeichen" -body {
    set result [pdf4tcllib::text::expandTabs "\tHello"]
    expr {[string first "\t" $result] == -1}
} -result 1

test text-tabs-width4 "Tab-Breite 4 am Anfang" -body {
    pdf4tcllib::text::expandTabs "\tX" 4
} -result "    X"

test text-tabs-width8 "Tab-Breite 8 am Anfang" -body {
    pdf4tcllib::text::expandTabs "\tX" 8
} -result "        X"

test text-tabs-mid "Tab in der Mitte rundet auf" -body {
    # "ab" = 2 Zeichen, naechster Tab-Stop bei 4
    set result [pdf4tcllib::text::expandTabs "ab\tX" 4]
    expr {$result eq "ab  X"}
} -result 1

test text-tabs-no-tab "Ohne Tabs unveraendert" -body {
    pdf4tcllib::text::expandTabs "Hello World" 4
} -result "Hello World"

test text-tabs-multiple "Mehrere Tabs" -body {
    set result [pdf4tcllib::text::expandTabs "A\tB\tC" 4]
    expr {[string first "\t" $result] == -1}
} -result 1

# ============================================================
# text::detectFont -- Font-Erkennung
# ============================================================

test text-detect-tab "Zeile mit Tab -> Monospace" -body {
    pdf4tcllib::text::detectFont "\tset x 1"
} -result "Courier"

test text-detect-indent "4-Leerzeichen-Einrueckung -> Monospace" -body {
    pdf4tcllib::text::detectFont "    set x 1"
} -result "Courier"

test text-detect-pipe "Pipe am Anfang -> Monospace" -body {
    pdf4tcllib::text::detectFont "  | Column1 | Column2 |"
} -result "Courier"

test text-detect-tclvar "Tcl-Variable -> Monospace" -body {
    pdf4tcllib::text::detectFont "puts \$myVar"
} -result "Courier"

test text-detect-namespace "Namespace-Operator -> Monospace" -body {
    pdf4tcllib::text::detectFont "::myns::myproc"
} -result "Courier"

test text-detect-normal "Normaler Text -> Sans" -body {
    set result [pdf4tcllib::text::detectFont "Dies ist normaler Text"]
    # Sollte Helvetica (default Sans) sein
    expr {$result eq "Helvetica" || $result eq "Pdf4tclSans"}
} -result 1

test text-detect-empty "Leerer String -> Sans" -body {
    set result [pdf4tcllib::text::detectFont ""]
    expr {$result eq "Helvetica" || $result eq "Pdf4tclSans"}
} -result 1

cleanupTests
