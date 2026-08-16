# test_page.tcl -- Tests fuer pdf4tcllib::page
package require tcltest
namespace import ::tcltest::*

# ============================================================
# page::context -- A4 Portrait
# ============================================================

test page-ctx-a4-paper "A4 context: Papiergroesse" -body {
    set ctx [pdf4tcllib::page::context a4]
    dict get $ctx paper
} -result "a4"

test page-ctx-a4-width "A4: Breite 595.28pt" -body {
    set ctx [pdf4tcllib::page::context a4]
    format "%.2f" [dict get $ctx page_w]
} -result "595.28"

test page-ctx-a4-height "A4: Hoehe 841.89pt" -body {
    set ctx [pdf4tcllib::page::context a4]
    format "%.2f" [dict get $ctx page_h]
} -result "841.89"

test page-ctx-a4-margin "A4 Default-Rand 20mm" -body {
    set ctx [pdf4tcllib::page::context a4]
    dict get $ctx margin_mm
} -result 20

test page-ctx-a4-textw "A4 Druckbreite < Seitenbreite" -body {
    set ctx [pdf4tcllib::page::context a4]
    expr {[dict get $ctx text_w] < [dict get $ctx page_w]}
} -result 1

test page-ctx-a4-texth "A4 Druckhoehe < Seitenhoehe" -body {
    set ctx [pdf4tcllib::page::context a4]
    expr {[dict get $ctx text_h] < [dict get $ctx page_h]}
} -result 1

test page-ctx-a4-left "A4 left = margin" -body {
    set ctx [pdf4tcllib::page::context a4]
    set diff [expr {abs([dict get $ctx left] - [dict get $ctx margin])}]
    expr {$diff < 0.01}
} -result 1

# ============================================================
# page::context -- Landscape
# ============================================================

test page-ctx-landscape "Landscape: Breite > Hoehe" -body {
    set ctx [pdf4tcllib::page::context a4 -landscape 1]
    expr {[dict get $ctx page_w] > [dict get $ctx page_h]}
} -result 1

test page-ctx-landscape-swap "Landscape: W/H vertauscht" -body {
    set p [pdf4tcllib::page::context a4]
    set l [pdf4tcllib::page::context a4 -landscape 1]
    set ok1 [expr {abs([dict get $p page_w] - [dict get $l page_h]) < 0.01}]
    set ok2 [expr {abs([dict get $p page_h] - [dict get $l page_w]) < 0.01}]
    expr {$ok1 && $ok2}
} -result 1

# ============================================================
# page::context -- Custom Margin
# ============================================================

test page-ctx-margin "Custom Margin 30mm" -body {
    set ctx [pdf4tcllib::page::context a4 -margin 30]
    dict get $ctx margin_mm
} -result 30

test page-ctx-margin-textw "Groesserer Rand = schmalere Druckbreite" -body {
    set c20 [pdf4tcllib::page::context a4 -margin 20]
    set c30 [pdf4tcllib::page::context a4 -margin 30]
    expr {[dict get $c20 text_w] > [dict get $c30 text_w]}
} -result 1

# ============================================================
# page::context -- Andere Papiergroessen
# ============================================================

test page-ctx-letter "Letter: 612 x 792pt" -body {
    set ctx [pdf4tcllib::page::context letter]
    list [format "%.0f" [dict get $ctx page_w]] [format "%.0f" [dict get $ctx page_h]]
} -result {612 792}

test page-ctx-a3 "A3: groesser als A4" -body {
    set a3 [pdf4tcllib::page::context a3]
    set a4 [pdf4tcllib::page::context a4]
    expr {[dict get $a3 page_w] > [dict get $a4 page_w]}
} -result 1

test page-ctx-a5 "A5: kleiner als A4" -body {
    set a5 [pdf4tcllib::page::context a5]
    set a4 [pdf4tcllib::page::context a4]
    expr {[dict get $a5 page_w] < [dict get $a4 page_w]}
} -result 1

# Prueft die MELDUNG, nicht nur den Fehler: die Liste der bekannten Groessen
# gehoert hinein, sonst weiss der Aufrufer nicht, was er stattdessen nehmen
# soll. (Der Text war deutsch und ist jetzt englisch -- die Projektregel
# sagt englische Meldungen. Dieser Test hing am alten Wortlaut.)
test page-ctx-unknown "unbekannte Groesse -> Fehler, der die bekannten nennt" -body {
    catch {pdf4tcllib::page::context xxl} err
    list [string match "*unknown paper size*" $err] [string match "*a4*" $err]
} -result {1 1}

# ============================================================
# page::context -- Dict-Vollstaendigkeit
# ============================================================

test page-ctx-keys "Context hat alle erwarteten Keys" -body {
    set ctx [pdf4tcllib::page::context a4]
    set keys {paper page_w page_h margin margin_mm left right top bottom text_w text_h}
    set missing {}
    foreach k $keys {
        if {![dict exists $ctx $k]} {
            lappend missing $k
        }
    }
    set missing
} -result {}

# ============================================================
# page::lineheight
# ============================================================

test page-lh-default "Lineheight 12pt, Faktor 1.4 = 17" -body {
    pdf4tcllib::page::lineheight 12
} -result 17

test page-lh-10 "Lineheight 10pt = 14" -body {
    pdf4tcllib::page::lineheight 10
} -result 14

test page-lh-custom "Lineheight 12pt, Faktor 1.2 = 15" -body {
    pdf4tcllib::page::lineheight 12 1.2
} -result 15

test page-lh-monoton "Groesserer Font = groessere Zeilenhoehe" -body {
    set h10 [pdf4tcllib::page::lineheight 10]
    set h14 [pdf4tcllib::page::lineheight 14]
    expr {$h14 > $h10}
} -result 1

# ============================================================
# Seitenbeschriftung im Fuss -- Dokumentinhalt, nicht Meldung
# ============================================================
#
# footer schrieb fest "Seite N" in jedes PDF, waehrend page::number
# daneben das sprachfreie "- 3 / 10 -" setzt. Die Vorgabe bleibt, damit
# bestehende Dokumente sich nicht stillschweigend aendern; einstellbar ist
# es jetzt zweifach.

proc pageFooterText {args} {
    set out [file join [file dirname [info script]] out zz-footer.pdf]
    file mkdir [file dirname $out]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set ctx [::pdf4tcllib::page::context a4]
    ::pdf4tcllib::page::footer $pdf $ctx "Fusstext" 3 9 {*}$args
    $pdf write -file $out
    $pdf destroy
    set txt ""
    catch {set txt [exec pdftotext $out -]}
    file delete $out
    return [string trim $txt]
}

# pdf4tcl is the one external dependency. Tests that need it are marked,
# so that a fresh clone WITHOUT pdf4tcl reports skips rather than failures
# -- a red suite is how a new reader decides the library is broken.
testConstraint pdf [expr {![catch {package require pdf4tcl}]}]

testConstraint pdftotext [expr {[llength [auto_execok pdftotext]] > 0}]

test page-label-1 "Vorgabe ist unveraendert Seite N" -constraints {pdf pdftotext} -body {
    string match "*Seite 3*" [pageFooterText]
} -result 1

test page-label-2 "-pagelabel setzt die Beschriftung je Aufruf" \
        -constraints {pdf pdftotext} -body {
    string match "*Page 3*" [pageFooterText -pagelabel "Page %s"]
} -result 1

test page-label-3 "die Namensraumvariable gilt fuer alle Aufrufe" \
        -constraints {pdf pdftotext} -body {
    set save $::pdf4tcllib::page::pageLabelFormat
    set ::pdf4tcllib::page::pageLabelFormat "p. %s"
    set got [pageFooterText]
    set ::pdf4tcllib::page::pageLabelFormat $save
    string match "*p. 3*" $got
} -result 1

test page-label-4 "unbekannte Option wird abgelehnt" -constraints pdf -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set ctx [::pdf4tcllib::page::context a4]
    catch {::pdf4tcllib::page::footer $pdf $ctx "x" 1 9 -quatsch 1} e
    $pdf destroy
    string match "*unknown option -quatsch*" $e
} -result 1


cleanupTests
