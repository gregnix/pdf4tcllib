# test_pdf4tcltemplate.tcl -- Tests fuer pdf4tcltemplate (Vorlage + Daten)
#
# Die Fragen: Liegt jeder Block, wo das Layout sagt, geht beim
# Seitenumbruch keine Zeile verloren oder doppelt, und haengt nichts von
# der Einheit des Dokuments ab? Gezaehlt wird im erzeugten PDF.

package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file join [file dirname [file normalize [info script]]] .. lib]

testConstraint template [expr {![catch {package require pdf4tcltemplate}]}]
testConstraint pdftotext [expr {[llength [auto_execok pdftotext]] > 0}]

set ::imgDir [file join [file dirname [file normalize [info script]]] images]

proc lyOut {name} {
    set d [file join [file dirname [file normalize [info script]]] out]
    file mkdir $d
    return [file join $d zz-layout-$name.pdf]
}

# Zeichnet und liefert {ergebnis text bbox-woerter}.
proc lyRun {layout data args} {
    set unit p
    if {[dict exists $args -unit]} {
        set unit [dict get $args -unit]
        set args [dict remove $args -unit]
    }
    set out [lyOut $unit]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -unit $unit]
    set res [::pdf4tcllib::template::render $pdf $layout $data {*}$args]
    $pdf write -file $out
    $pdf destroy
    set txt ""
    catch {set txt [exec pdftotext -layout $out -]}
    set box ""
    catch {set box [exec pdftotext -bbox $out -]}
    file delete $out
    set words [regexp -all -inline {<word [^>]*>[^<]*</word>} $box]
    return [list $res $txt $words]
}

proc lyRows {n} {
    set rows {}
    for {set i 1} {$i <= $n} {incr i} {
        lappend rows [list pos $i text "ZEILE$i Schrauben M8 verzinkt" menge [expr {$i * 10}]]
    }
    return $rows
}

set ::lsLayout {
    paper a4 margin 20 size 10
    blocks {
        kopf     {x 20 y 18 w 110 size 16 bold 1}
        adresse  {x 20 y 50 w 85 list 1}
        meta     {type pairs x 125 y 50 w 65 labelw 30}
        titel    {x 20 y 95 w 170 size 14 bold 1 text "Lieferschein {nummer}"}
        tabelle  {type table x 20 y 108 w 170
                  cols {{key pos title Pos w 12 align right} {key text title Bezeichnung}
                        {key menge title Menge w 25 align right}}}
        schluss  {x 20 y 0 w 170 gap 6 text "SCHLUSS Vielen Dank."}
        fuss     {x 20 y 282 w 170 size 8 page all align center text "Seite {page} von {pages}"}
    }
}

# ============================================================
# check
# ============================================================

test ly-ns-1 "eigener Namensraum; layout:: des Hauptpakets bleibt unberuehrt" -constraints template -body {
    list [llength [info commands ::pdf4tcllib::template::render]] \
        [llength [info commands ::pdf4tcllib::layout::render]] \
        [llength [info commands ::pdf4tcllib::layout::stack]]
} -result {1 0 1}

test ly-check-1 "Vorgaben werden eingesetzt" -constraints template -body {
    set l [::pdf4tcllib::template::check {blocks {a {x 20 y 20 w 50}}}]
    list [dict get $l paper] [dict get $l margin] [dict get $l top] \
        [dict get $l bottom] [dict get $l blocks a type]
} -result {a4 20 20 277 text}

test ly-check-2 "unbekannter Typ mit Code" -constraints template -body {
    catch {::pdf4tcllib::template::check {blocks {a {type kreis}}}} m o
    list [dict get $o -errorcode] [string match *kreis* $m]
} -result {{PDF4TCLLIB TEMPLATE TYPE} 1}

test ly-check-3 "falsche Werte" -constraints template -body {
    set r {}
    foreach b {
        {x -1}  {w abc}  {show vielleicht}  {align mitte}  {page jede}
        {y 0 page all}  {x 200 w 20}  {type table w 100}  {type image w 10}
        {type table w 30 cols {{key a w 20} {key b w 20}}}
    } {
        catch {::pdf4tcllib::template::check [list blocks [list a $b]]} m o
        lappend r [lindex [dict get $o -errorcode] 2]
    }
    return $r
} -result {VALUE VALUE VALUE VALUE VALUE VALUE VALUE VALUE VALUE VALUE}

test ly-check-4 "Spalten ohne Breite teilen den Rest" -constraints template -body {
    set l [::pdf4tcllib::template::check {blocks {t {type table x 20 y 20 w 100
        cols {{key a w 20} b c}}}}]
    lmap c [dict get $l blocks t cols] { dict get $c w }
} -result {20 40.0 40.0}

test ly-check-5 "Papier: Name oder Masse" -constraints template -body {
    list [::pdf4tcllib::template::paperSize A5] [::pdf4tcllib::template::paperSize {100 150}] \
        [catch {::pdf4tcllib::template::paperSize b9}]
} -result {{148 210} {100 150} 1}

test ly-check-6 "unbekannte Option von render" -constraints template -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    catch {::pdf4tcllib::template::render $pdf {blocks {a {x 20 y 20}}} {} -schrift x} m o
    $pdf destroy
    dict get $o -errorcode
} -result {PDF4TCLLIB TEMPLATE OPTION}

test ly-check-7 "orient 0 wird abgelehnt" -constraints template -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 0]
    catch {::pdf4tcllib::template::render $pdf {blocks {a {x 20 y 20 text x}}} {}} m o
    $pdf destroy
    dict get $o -errorcode
} -result {PDF4TCLLIB TEMPLATE ORIENT}

# ============================================================
# Texte
# ============================================================

test ly-text-1 "Platzhalter aus den Daten, fehlende Daten: Block entfaellt" \
        -constraints {template pdftotext} -body {
    lassign [lyRun {blocks {
        a {x 20 y 20 w 170 text "Nummer {nr}"}
        b {x 20 y 40 w 170}
        c {x 20 y 60 w 170}
    }} {nr LS-7 c Wert}] res txt
    list [regexp {Nummer LS-7} $txt] [regexp {Wert} $txt] [dict get $res pages]
} -result {1 1 1}

test ly-text-2 "Zeilenumbruch im Text wird zu Zeilen, kein Zeichen" \
        -constraints {template pdftotext} -body {
    lassign [lyRun {blocks {a {x 20 y 20 w 170}}} [dict create a "EINS\nZWEI"]] res txt words
    list [llength [lsearch -all -regexp $words {>EINS<|>ZWEI<}]] \
        [regexp {EINS\s*\n\s*ZWEI} $txt]
} -result {2 1}

test ly-text-3 "Liste: leere Eintraege fallen weg" -constraints {template pdftotext} -body {
    lassign [lyRun {blocks {a {x 20 y 20 w 170 list 1}}} {a {{Firma A} {} {Weg 1} {}}}] res txt
    regexp {Firma A\s*\n\s*Weg 1} $txt
} -result 1

test ly-text-4 "langer Text bricht im Block um" -constraints {template pdftotext} -body {
    set t [string repeat "Wort " 60]
    lassign [lyRun {blocks {a {x 20 y 20 w 60}}} [dict create a $t]] res txt
    expr {[llength [regexp -all -inline {Wort} $txt]] == 60
          && [llength [split [string trim $txt] \n]] > 5}
} -result 1

test ly-text-5 "rechtsbuendig endet am Blockrand" -constraints {template pdftotext} -body {
    lassign [lyRun {blocks {a {x 20 y 20 w 100 align right}}} {a RECHTS}] res txt words
    regexp {xMax="([0-9.]+)"} [lindex $words 0] -> xmax
    # 120 mm = 340.2 pt
    expr {abs($xmax - 120 * 72 / 25.4) < 1.5}
} -result 1

test ly-text-6 "Zahlenartige Woerter bleiben wie geschrieben" -constraints {template pdftotext} -body {
    lassign [lyRun {blocks {a {x 20 y 20 w 170 list 1}}} {a {+49 007 0x10 1e3}}] res txt
    regexp -all -inline {\S+} $txt
} -result {+49 007 0x10 1e3}

test ly-pairs-1 "Paare: leere Werte fallen weg" -constraints {template pdftotext} -body {
    lassign [lyRun {blocks {m {type pairs x 20 y 20 w 100 labelw 40}}} \
        {m {Nummer LS-1 Leer {} Datum 08.11.2026}}] res txt
    list [regexp {Nummer\s+LS-1} $txt] [regexp {Leer} $txt] [regexp {Datum\s+08.11.2026} $txt]
} -result {1 0 1}

# ============================================================
# Tabelle und Seitenumbruch
# ============================================================

test ly-table-1 "60 Zeilen: jede genau einmal, Kopf auf jeder Seite" \
        -constraints {template pdftotext} -body {
    lassign [lyRun $::lsLayout [dict create nummer LS-9 tabelle [lyRows 80]]] res txt
    set fehlt {}
    for {set i 1} {$i <= 80} {incr i} {
        if {[llength [regexp -all -inline "ZEILE$i " $txt]] != 1} { lappend fehlt $i }
    }
    set n [dict get $res pages]
    list $fehlt [expr {$n >= 2}] \
        [expr {[llength [regexp -all -inline {Pos\s+Bezeichnung} $txt]] == $n}]
} -result {{} 1 1}

test ly-table-2 "Block im Fluss steht nach der Tabelle, auf der letzten Seite" \
        -constraints {template pdftotext} -body {
    lassign [lyRun $::lsLayout [dict create nummer LS-9 tabelle [lyRows 80]]] res txt
    set seiten [split $txt \f]
    list [regexp {SCHLUSS} [lindex $seiten [dict get $res pages]-1]] \
        [expr {[string first ZEILE80 $txt] < [string first SCHLUSS $txt]}]
} -result {1 1}

test ly-table-3 "Seite {page} von {pages} auf jeder Seite" -constraints {template pdftotext} -body {
    lassign [lyRun $::lsLayout [dict create nummer LS-9 tabelle [lyRows 80]]] res txt
    set n [dict get $res pages]
    set soll {}
    for {set i 1} {$i <= $n} {incr i} { lappend soll "Seite $i von $n" }
    expr {[regexp -all -inline {Seite \d+ von \d+} $txt] eq $soll && $n >= 2}
} -result 1

test ly-table-4 "Zeilen als Listen in Spaltenfolge" -constraints {template pdftotext} -body {
    lassign [lyRun {blocks {t {type table x 20 y 20 w 170 cols {a b}}}} \
        {t {{LINKS RECHTS}}}] res txt
    regexp {LINKS\s+RECHTS} $txt
} -result 1

test ly-table-5 "-newpage laeuft bei jedem Umbruch" -constraints template -body {
    set ::n 0
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set res [::pdf4tcllib::template::render $pdf $::lsLayout \
        [dict create nummer X tabelle [lyRows 80]] -newpage {incr ::n}]
    $pdf destroy
    expr {$::n == [dict get $res pages] - 1 && $::n >= 1}
} -result 1

# ============================================================
# Einheiten
# ============================================================

test ly-unit-1 "pt und mm ergeben dieselben Positionen" -constraints {template pdftotext} -body {
    set d [dict create nummer LS-9 tabelle [lyRows 30] adresse {{Firma A} {Weg 1}} \
        meta {Nummer LS-9 Datum 08.11.2026}]
    lassign [lyRun $::lsLayout $d -unit p] r1 t1 w1
    lassign [lyRun $::lsLayout $d -unit mm] r2 t2 w2
    list [expr {$w1 eq $w2}] [llength $w1] [expr {[dict get $r1 pages] == [dict get $r2 pages]}]
} -match glob -result {1 * 1}

test ly-unit-2 "Block liegt an x/y des Layouts" -constraints {template pdftotext} -body {
    lassign [lyRun {blocks {a {x 50 y 100 w 100 size 10}}} {a MARKE} -unit mm] res txt words
    regexp {xMin="([0-9.]+)" yMin="([0-9.]+)"} [lindex $words 0] -> x y
    # x 50 mm = 141.7 pt; die Oberkante der Schrift liegt knapp unter y 100 mm
    list [expr {abs($x - 50 * 72 / 25.4) < 1}] [expr {$y >= 100 * 72 / 25.4 - 1 && $y < 100 * 72 / 25.4 + 4}]
} -result {1 1}

# ============================================================
# Bild
# ============================================================

test ly-image-1 "Bild passt in w x h, Seitenverhaeltnis bleibt" -constraints template -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -unit mm]
    set res [::pdf4tcllib::template::render $pdf \
        {blocks {logo {type image x 150 y 10 w 40 h 40} t {x 20 y 0 w 100 text danach}}} \
        [dict create logo [file join $::imgDir testbild-100x83.png]]]
    $pdf destroy
    # 100x83 in 40x40: 40 breit, 33.2 hoch; der Text darunter beginnt dort
    expr {[dict get $res y] > 43 && [dict get $res y] < 49}
} -result 1

test ly-image-2 "fehlende Bilddatei mit Code" -constraints template -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    catch {::pdf4tcllib::template::render $pdf {blocks {l {type image x 0 y 5 w 10 h 10 page all}}} \
        {l /gibt/es/nicht.png}} m o
    $pdf destroy
    dict get $o -errorcode
} -result {PDF4TCLLIB TEMPLATE DATA}

# ============================================================
# Farben, Linie, Auszeichnung
# ============================================================

test ly-color-1 "Farbe: Thema, r g b, Standardnamen; unbekannt mit Code" -constraints template -body {
    set l {theme {haus {0.1 0.2 0.3}}}
    list [::pdf4tcllib::template::_color $l haus] [::pdf4tcllib::template::_color $l {1 0 0}] \
        [::pdf4tcllib::template::_color $l rule] \
        [lindex [catch {::pdf4tcllib::template::_color $l lila} m o] 0][lindex [dict get $o -errorcode] 2]
} -result {{0.1 0.2 0.3} {1 0 0} {0.6 0.6 0.6} 1VALUE}

test ly-tag-1 "mit tagged 1 bleibt nichts unausgezeichnet" -constraints template -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    ::pdf4tcllib::template::render $pdf {blocks {
        a {x 20 y 20 w 100 text Hallo}
        r {type rule x 20 y 30 w 100}
        t {type table x 20 y 40 w 100 cols {a b}}
        m {type pairs x 20 y 100 w 100}
    }} {t {{1 2} {3 4}} m {X Y}}
    set n [$pdf getUntaggedCount]
    $pdf destroy
    return $n
} -result 0

# ============================================================
# Zeilenarten der Tabelle: Gruppenkopf, Summe, ueber alle Spalten
# ============================================================

# Zeilenhoehe bei size 10: Zeilenabstand 1.3 * 10 pt plus 1 mm Rand
set ::rh [expr {10 * 1.3 / 72.0 * 25.4 + 1.0}]

# Layout ohne Tabellenkopf: genau k Zeilen passen auf eine Seite
# (plus d mm Luft); die Tabelle beginnt oben am Fluss
proc rowsLayout {k {d 0}} {
    set bottom [expr {20 + $k * $::rh + $d}]
    dict create paper a4 margin 20 top 20 bottom $bottom size 10 blocks [dict create \
        t [dict create type table x 20 y 20 w 170 header 0 cols {{key a w 30} {key b}}]]
}

proc rowsN {n {pre R}} {
    set r {}
    for {set i 1} {$i <= $n} {incr i} { lappend r [dict create a $pre$i b x] }
    return $r
}

# Text je Seite
proc pageTexts {txt} { split [string trimright $txt \f] \f }

test ly-rows-1 "Gruppenkopf ueber alle Spalten, fett; Summe darunter" -constraints {template pdftotext} -body {
    set rows [list [dict create _kind group a "Kunde: Mueller GmbH und Soehne Kommanditgesellschaft"] \
        [dict create a R1 b 10,00] [dict create a R2 b 20,00] [dict create _kind sum a Summe b 30,00] \
        [dict create _span 1 _text "Hinweis ueber die ganze Breite der Tabelle ohne Umbruch"]]
    lassign [lyRun {blocks {t {type table x 20 y 20 w 170 cols {{key a w 30} {key b}}}}} \
        [dict create t $rows]] res txt
    list [regexp {Kunde: Mueller GmbH und Soehne Kommanditgesellschaft} $txt] \
        [regexp {Summe\s+30,00} $txt] \
        [regexp {Hinweis ueber die ganze Breite der Tabelle ohne Umbruch} $txt] [dict get $res pages]
} -result {1 1 1 1}

test ly-rows-2 "Zeilen fuellen die Seite genau: keine leere zweite Seite" -constraints template -body {
    lassign [lyRun [rowsLayout 10] [dict create t [rowsN 10]]] res
    dict get $res pages
} -result 1

test ly-rows-3 "1 mm zu wenig Platz: die letzte Zeile kommt auf Seite 2" -constraints {template pdftotext} -body {
    lassign [lyRun [rowsLayout 10 -1] [dict create t [rowsN 10]]] res txt
    set s [pageTexts $txt]
    list [dict get $res pages] [regexp {R10\M} [lindex $s 0]] [regexp {R10\M} [lindex $s 1]]
} -result {2 0 1}

test ly-rows-4 "Gruppenkopf am Seitenende wandert mit der naechsten Zeile" -constraints {template pdftotext} -body {
    set rows [concat [rowsN 9] [list [dict create _kind group a KOPF] [dict create a NACH b x]]]
    lassign [lyRun [rowsLayout 10] [dict create t $rows]] res txt
    set s [pageTexts $txt]
    list [dict get $res pages] [regexp KOPF [lindex $s 0]] [regexp {KOPF.*NACH} [lindex $s 1]]
} -result {2 0 1}

test ly-rows-5 "Summe nicht allein oben: die letzte Zeile geht mit" -constraints {template pdftotext} -body {
    set rows [concat [rowsN 10] [list [dict create _kind sum a SUMME b 1]]]
    lassign [lyRun [rowsLayout 10] [dict create t $rows]] res txt
    set s [pageTexts $txt]
    list [dict get $res pages] [regexp {R10\M} [lindex $s 0]] [regexp {R10\M.*SUMME} [lindex $s 1]]
} -result {2 0 1}

test ly-rows-6 "Kette laenger als eine Seite: Zeile fuer Zeile, jede genau einmal" -constraints {template pdftotext} -body {
    set rows [list [dict create a A b x]]
    for {set i 1} {$i <= 25} {incr i} { lappend rows [dict create _kind sum a S$i b x] }
    lassign [lyRun [rowsLayout 10] [dict create t $rows]] res txt
    set fehlt {}
    for {set i 1} {$i <= 25} {incr i} {
        if {[llength [regexp -all -inline "S$i\\M" $txt]] != 1} { lappend fehlt $i }
    }
    list [dict get $res pages] $fehlt
} -result {3 {}}

test ly-rows-7 "Unbekannte Zeilenart ist ein Fehler" -constraints template -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set c [catch {::pdf4tcllib::template::render $pdf {blocks {t {type table x 20 y 20 w 100 cols {a b}}}} \
        {t {{_kind kreis a 1}}}} m o]
    $pdf destroy
    list $c [lrange [dict get $o -errorcode] 0 2]
} -result {1 {PDF4TCLLIB TEMPLATE DATA}}

test ly-rows-8 "Zeilenarten mit tagged 1: nichts unausgezeichnet" -constraints template -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    ::pdf4tcllib::template::render $pdf {blocks {t {type table x 20 y 20 w 100 cols {a b}}}} \
        {t {{_kind group a K} {a 1 b 2} {_kind total a S b 2}}}
    set n [$pdf getUntaggedCount]
    $pdf destroy
    return $n
} -result 0

test ly-rows-9 "Kopfzeile wiederholt sich auch vor einer gewanderten Kette" -constraints {template pdftotext} -body {
    set l [rowsLayout 10]
    dict set l blocks t header 1
    dict set l blocks t cols {{key a w 30 title SPALTEA} {key b title SPALTEB}}
    set rows [concat [rowsN 8] [list [dict create _kind group a KOPF] [dict create a NACH b x]]]
    lassign [lyRun $l [dict create t $rows]] res txt
    set s [pageTexts $txt]
    list [dict get $res pages] [regexp {SPALTEA.*KOPF} [lindex $s 1]]
} -result {2 1}

cleanupTests
