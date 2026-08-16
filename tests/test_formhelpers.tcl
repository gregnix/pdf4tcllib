# test_formhelpers.tcl -- Tests fuer pdf4tcllib::form und ::forms
#
# test_forms.tcl prueft die Vorlagen und die Schema-Schluessel. Was dort
# fehlt, ist die Schicht darunter: die Geometrie der Bausteine und die
# Frage, was in der erzeugten Datei ankommt. Genau dort lag der Fund, der
# diese Datei ausgeloest hat -- orderTable zeichnete klaglos ueber den
# Blattrand hinaus.

package require tcltest
namespace import ::tcltest::*

testConstraint forms [expr {![catch {package require pdf4tclforms}]}]
testConstraint pdf   [expr {![catch {package require pdf4tcl}]}]

# Ein frisches Dokument mit offener Seite und Kontext.
proc fhNew {} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    return [list $pdf [::pdf4tcllib::page::context a4]]
}

# Schreibt das Dokument und liefert seinen Rohtext zurueck (latin-1, damit
# die Bytes erhalten bleiben) -- daraus lesen die Tests /Rect, /FT und /T.
proc fhWrite {pdf} {
    set out [file join [file dirname [info script]] out zz-formhelpers.pdf]
    file mkdir [file dirname $out]
    $pdf write -file $out
    set fh [open $out rb]
    fconfigure $fh -encoding iso8859-1 -translation binary
    set d [read $fh]
    close $fh
    file delete $out
    return $d
}

proc fhRects {raw} {
    set out {}
    foreach {full body} [regexp -all -inline {/Rect\s*\[([^\]]*)\]} $raw] {
        lassign $body x0 y0 x1 y1
        lappend out [list [expr {$x1 - $x0}] [expr {$y1 - $y0}]]
    }
    return $out
}

proc fhFieldNames {raw} {
    set out {}
    foreach {full name} [regexp -all -inline {/T\s*\(([^)]*)\)} $raw] {
        lappend out $name
    }
    return [lsort $out]
}

# ============================================================
# Konfiguration und Hoehenarithmetik
# ============================================================

test fh-cfg-1 "configure ohne Argumente liefert die Konfiguration" \
        -constraints forms -body {
    set cfg [::pdf4tcllib::form::configure]
    expr {[dict exists $cfg fieldH] && [dict exists $cfg rowGap]}
} -result 1

test fh-cfg-2 "rowHeight ist fieldHeight plus Zeilenabstand" -constraints forms -body {
    set cfg [::pdf4tcllib::form::configure]
    expr {[::pdf4tcllib::form::rowHeight]
          == [::pdf4tcllib::form::fieldHeight] + [dict get $cfg rowGap]}
} -result 1

test fh-cfg-3 "gesetzte Werte kommen zurueck, und zwar genau die gesetzten" \
        -constraints forms -body {
    set save [::pdf4tcllib::form::fieldHeight]
    ::pdf4tcllib::form::configure -fieldH 33
    set got [::pdf4tcllib::form::fieldHeight]
    ::pdf4tcllib::form::configure -fieldH $save
    list $got [::pdf4tcllib::form::fieldHeight]
} -result [list 33 [expr {[::pdf4tcllib::form::fieldHeight]}]]

test fh-cfg-4 "unbekannte Option wird abgelehnt" -constraints forms -body {
    catch {::pdf4tcllib::form::configure -gibtsnicht 1} e
    string match "*unknown option*" $e
} -result 1

# ============================================================
# orderTable -- der Fund, der diese Datei ausgeloest hat
# ============================================================
#
# Die Doku sagt seit jeher "Summe <= SW". Geprueft hat das niemand:
# zwei Spalten zu je SW ergaben eine Tabelle, deren rechte Kante bei
# 1020 pt auf einem 595-pt-Blatt lag. Gueltiges PDF, unsichtbarer Inhalt,
# keine Meldung.

test fh-order-1 "passende Spaltenbreiten laufen durch" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::form::orderTable $pdf $ctx y {A B} {100 200} {{x y}}
    $pdf destroy
    expr {$y > 100}
} -result 1

test fh-order-2 "zu breite Spalten werden abgelehnt" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    set sw [dict get $ctx SW]
    catch {::pdf4tcllib::form::orderTable $pdf $ctx y {A B} [list $sw $sw] {{x y}}} e
    $pdf destroy
    string match "*past the edge of the page*" $e
} -result 1

test fh-order-3 "die Meldung nennt beide Zahlen" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    set sw [dict get $ctx SW]
    catch {::pdf4tcllib::form::orderTable $pdf $ctx y {A B} [list $sw $sw] {{x y}}} e
    $pdf destroy
    # Eine Meldung, die nur "zu breit" sagt, hilft beim Rechnen nicht.
    list [regexp {963\.8} $e] [regexp {481\.9} $e]
} -result {1 1}

test fh-order-4 "eine halbe Punktbreite Toleranz fuer Rundung" \
        -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    set sw [dict get $ctx SW]
    set rc [catch {::pdf4tcllib::form::orderTable $pdf $ctx y {A} \
            [list [expr {$sw + 0.4}]] {{x}}} e]
    $pdf destroy
    return $rc
} -result 0

test fh-order-5 "weniger Breiten als Spalten wird gemeldet" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    catch {::pdf4tcllib::form::orderTable $pdf $ctx y {A B C} {100 100} {{x y z}}} e
    $pdf destroy
    string match "*3 header(s) but only 2 column width(s)*" $e
} -result 1

test fh-order-6 "-cellForm erzeugt ein Feld je Zelle" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::form::orderTable $pdf $ctx y {A B} {100 100} {{x y} {u v}} \
        -cellForm pos
    set names [fhFieldNames [fhWrite $pdf]]
    $pdf destroy
    # zwei Zeilen mal zwei Spalten
    llength $names
} -result 4

test fh-order-7 "-emptyRows haengt Zeilen an und kostet Hoehe" \
        -constraints {forms pdf} -body {
    set ys {}
    foreach n {0 3} {
        lassign [fhNew] pdf ctx
        set y 100
        ::pdf4tcllib::form::orderTable $pdf $ctx y {A} {100} {{x}} -emptyRows $n
        lappend ys $y
        $pdf destroy
    }
    expr {[lindex $ys 1] > [lindex $ys 0]}
} -result 1

# ============================================================
# row -- die Klemmung, die ein Feld nicht verschwinden laesst
# ============================================================
#
# Ein langes Label bei kleiner Gesamtbreite koennte das Feld auf 0 oder
# negativ druecken; das Feld wuerde dann das naechste Label ueberschreiben.

test fh-row-1 "ein Feld bekommt nie eine Breite <= 0" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::form::row $pdf $ctx y [list \
        [dict create label "Ein wirklich sehr langes Label das alles sprengt:" \
                     type text width 10 id f1]]
    set bad {}
    foreach r [fhRects [fhWrite $pdf]] {
        lassign $r w h
        if {$w <= 0} { lappend bad $w }
    }
    $pdf destroy
    return $bad
} -result {}

test fh-row-2 "zwei Paare ergeben zwei Felder" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::form::row $pdf $ctx y [list \
        [dict create label "A:" type text width 200 id f_a] \
        [dict create label "B:" type text width 200 id f_b]]
    set names [fhFieldNames [fhWrite $pdf]]
    $pdf destroy
    return $names
} -result {f_a f_b}

test fh-row-3 "eine Zeile kostet genau eine Zeilenhoehe" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::form::row $pdf $ctx y [list \
        [dict create label "A:" type text width 200 id f_a]]
    $pdf destroy
    expr {$y - 100}
} -result [expr {[::pdf4tcllib::form::rowHeight]}]

# ============================================================
# labelField und separator
# ============================================================

test fh-label-1 "labelField erzeugt ein Feld mit dem gegebenen Namen" \
        -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::form::labelField $pdf $ctx y "Name:" text -id f_name
    set names [fhFieldNames [fhWrite $pdf]]
    $pdf destroy
    return $names
} -result f_name

test fh-label-2 "checkbox wird ein Btn-Feld, text ein Tx-Feld" \
        -constraints {forms pdf} -body {
    set out {}
    foreach t {text checkbox} {
        lassign [fhNew] pdf ctx
        set y 100
        ::pdf4tcllib::form::labelField $pdf $ctx y "X:" $t -id f_x
        set raw [fhWrite $pdf]
        $pdf destroy
        lappend out [lsort -unique [regexp -all -inline {/FT\s*/(\w+)} $raw]]
    }
    # regexp -all -inline liefert Vollmatch und Gruppe; nur die Gruppen zaehlen
    list [expr {"Tx" in [lindex $out 0]}] [expr {"Btn" in [lindex $out 1]}]
} -result {1 1}

test fh-sep-1 "separator verschiebt y nach unten" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::form::separator $pdf $ctx y
    $pdf destroy
    expr {$y > 100}
} -result 1

# ============================================================
# forms:: -- Felder aus einer Spezifikation
# ============================================================

test fh-field-1 "ein Feld ohne type ist ein Textfeld" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::forms::field $pdf $ctx y {label "Ohne Typ:" id f_notype}
    set raw [fhWrite $pdf]
    $pdf destroy
    list [fhFieldNames $raw] [expr {[regexp {/FT\s*/Tx} $raw] ? 1 : 0}]
} -result {f_notype 1}

test fh-field-2 "unbekannter Feldtyp wird gemeldet" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    catch {::pdf4tcllib::forms::field $pdf $ctx y {label "X:" type gibtsnicht id f9}} e
    $pdf destroy
    string match "*unknown form type*" $e
} -result 1

test fh-field-3 "ein mehrzeiliges Feld ist hoeher als ein einzeiliges" \
        -constraints {forms pdf} -body {
    set hs {}
    foreach spec [list {label "A:" type text id f_a} \
                       {label "A:" type text id f_a multiline 1 fieldh 60}] {
        lassign [fhNew] pdf ctx
        set y 100
        ::pdf4tcllib::forms::field $pdf $ctx y $spec
        set r [lindex [fhRects [fhWrite $pdf]] 0]
        $pdf destroy
        lappend hs [lindex $r 1]
    }
    expr {[lindex $hs 1] > [lindex $hs 0]}
} -result 1

test fh-checkbox-1 "checkboxLine erzeugt ein Btn-Feld" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    ::pdf4tcllib::forms::checkboxLine $pdf $ctx y {label "Erledigt" id f_done}
    set raw [fhWrite $pdf]
    $pdf destroy
    list [fhFieldNames $raw] [expr {[regexp {/FT\s*/Btn} $raw] ? 1 : 0}]
} -result {f_done 1}

test fh-schema-1 "renderSchema ohne sections wird gemeldet" -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 100
    catch {::pdf4tcllib::forms::renderSchema $pdf $ctx {title "T"} -yvar y} e
    $pdf destroy
    string match "*needs 'sections' key*" $e
} -result 1

test fh-schema-2 "renderSchema schiebt y weiter und erzeugt die Felder" \
        -constraints {forms pdf} -body {
    lassign [fhNew] pdf ctx
    set y 60
    # sections ist ein DICT (Name -> Sektion), keine Liste. Eine Liste
    # laesst renderSchema an `dict for` scheitern -- meine erste Fassung
    # dieses Tests machte genau diesen Fehler.
    set spec [dict create title "Test" sections [dict create \
        teil1 [dict create title "Teil 1" fields [list \
            [dict create label "Name:" type text id s_name] \
            [dict create label "Ort:"  type text id s_ort]]]]]
    ::pdf4tcllib::forms::renderSchema $pdf $ctx $spec -yvar y
    set names [fhFieldNames [fhWrite $pdf]]
    $pdf destroy
    list $names [expr {$y > 60}]
} -result {{s_name s_ort} 1}

test fh-schema-3 "sections als Liste statt Dict wird benannt" \
        -constraints {forms pdf} -body {
    # Ohne diese Pruefung scheiterte `dict for` mit "missing value to go
    # with key" -- eine Meldung, die auf die Bibliothek zeigt statt auf die
    # Spezifikation des Aufrufers.
    lassign [fhNew] pdf ctx
    set y 60
    set spec [dict create title "T" sections [list \
        [dict create title "S" fields {}]]]
    catch {::pdf4tcllib::forms::renderSchema $pdf $ctx $spec -yvar y} e
    $pdf destroy
    string match "*'sections' must be a dict*" $e
} -result 1

cleanupTests
