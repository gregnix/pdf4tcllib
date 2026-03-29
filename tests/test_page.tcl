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

test page-ctx-unknown "Unbekannte Groesse -> Fehler" -body {
    catch {pdf4tcllib::page::context xxl} err
    string match "*Unbekannte*" $err
} -result 1

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

cleanupTests
