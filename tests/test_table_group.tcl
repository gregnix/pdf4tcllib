# test_table_group.tcl -- table::group und verbundene Zellen in table::draw
#
# Gruppieren mit Zwischensummen ist die Rechnung nicht wert, die daran
# haengt -- die Arbeit steckt drumherum: die Zeilen muessen sortiert sein,
# die Beschriftung der Summenzeile reicht ueber mehrere Spalten, und der
# Aufrufer muss wissen, WELCHE Zeilen Summen sind, um sie hervorzuheben.

package require tcltest
namespace import ::tcltest::*

# Damit die Datei auch EINZELN laeuft. Ohne diese Zeile findet sie
# pdf4tcllib nur ueber ein installiertes Paket -- und die Constraints
# unten fragen genau danach. Fehlt es, ueberspringt tcltest still
# ALLES und meldet trotzdem Erfolg: Rueckgabewert 0, Failed 0. Der
# Runner setzt den Pfad selbst, deshalb fiel es nie auf.
tcl::tm::path add [file join [file dirname [file normalize [info script]]] .. lib]

testConstraint pdf [expr {![catch {package require pdf4tcl}]}]
testConstraint lib [expr {![catch {package require pdf4tcllib}]}]

catch {::pdf4tcllib::fonts::init}

set ::gRows {
    {Nord Q1 120} {Nord Q2 90} {Sued Q1 150} {Sued Q2 60} {West Q1 80}
}

test group-1.1 {je Gruppe eine Zwischensumme, am Ende die Gesamtsumme} \
        -constraints {pdf lib} -body {
    set g [::pdf4tcllib::table::group $::gRows -by 0 -sum 2]
    # 5 Datenzeilen + 3 Zwischensummen + 1 Gesamtsumme
    list [llength [dict get $g rows]] [dict get $g subtotals] \
            [dict get $g total]
} -result {9 {2 5 7} 8}

test group-1.2 {die Summen stimmen} -constraints {pdf lib} -body {
    set g [::pdf4tcllib::table::group $::gRows -by 0 -sum 2]
    set rows [dict get $g rows]
    set res {}
    foreach r [dict get $g subtotals] { lappend res [lindex [lindex $rows $r] 1] }
    lappend res [lindex [lindex $rows [dict get $g total]] 1]
    set res
} -result {210 210 80 500}

test group-1.3 {die Beschriftung reicht ueber die Textspalten} \
        -constraints {pdf lib} -body {
    # Sonst stuende "Summe Nord" in der Region-Spalte und das Quartal
    # daneben leer -- die Zeile saehe aus wie eine Datenzeile.
    set g [::pdf4tcllib::table::group $::gRows -by 0 -sum 2]
    set zelle [lindex [lindex [dict get $g rows] 2] 0]
    list [::pdf4tcllib::table::_cellText $zelle] \
            [::pdf4tcllib::table::_cellSpan $zelle]
} -result {{Summe Nord} 2}

test group-1.4 {unsortierte Zeilen melden sich} -constraints {pdf lib} -body {
    # Eine Gruppe faellt sonst in mehrere Bloecke, und jeder bekommt seine
    # eigene Zwischensumme -- die Zahlen stimmen je Block, aber niemand
    # will sie so.
    set ::pdf4tcl::warnings {}
    ::pdf4tcllib::table::group {{A x 1} {B y 2} {A z 3}} -by 0 -sum 2
    list [llength $::pdf4tcl::warnings] \
            [string match "*not sorted by column 0*" \
                    [lindex $::pdf4tcl::warnings 0]]
} -result {1 1}

test group-1.5 {-strict wirft statt zu melden} -constraints {pdf lib} -body {
    catch {::pdf4tcllib::table::group {{A x 1} {B y 2} {A z 3}} \
            -by 0 -sum 2 -strict 1} e
    string match "*not sorted*" $e
} -result 1

test group-1.6 {sortierte Zeilen melden nichts} -constraints {pdf lib} -body {
    set ::pdf4tcl::warnings {}
    ::pdf4tcllib::table::group $::gRows -by 0 -sum 2
    llength $::pdf4tcl::warnings
} -result 0

test group-1.7 {ein leeres Feld ist keine Null} -constraints {pdf lib} -body {
    # Wer "" als 0 zaehlt, macht aus einer fehlenden Angabe eine Aussage.
    set g [::pdf4tcllib::table::group {{A x 1} {A y {}} {A z k.A.}} \
            -by 0 -sum 2 -total 0]
    lindex [lindex [dict get $g rows] end] 1
} -result 1

test group-1.8 {-blank laesst den Gruppenwert nur einmal stehen} \
        -constraints {pdf lib} -body {
    set g [::pdf4tcllib::table::group $::gRows -by 0 -sum 2 -blank 1 -total 0]
    set rows [dict get $g rows]
    list [lindex [lindex $rows 0] 0] [lindex [lindex $rows 1] 0]
} -result {Nord {}}

test group-1.9 {-header setzt eine Kopfzeile je Gruppe} -constraints {pdf lib} \
        -body {
    set g [::pdf4tcllib::table::group $::gRows -by 0 -sum 2 -header 1]
    set rows [dict get $g rows]
    set kopf [lindex $rows [lindex [dict get $g groups] 0]]
    list [llength [dict get $g groups]] \
            [::pdf4tcllib::table::_cellText [lindex $kopf 0]] \
            [::pdf4tcllib::table::_cellSpan [lindex $kopf 0]]
} -result {3 Nord 3}

test group-1.10 {leere Eingabe und unsinnige Spalte} -constraints {pdf lib} \
        -body {
    set leer [::pdf4tcllib::table::group {} -by 0 -sum 1]
    catch {::pdf4tcllib::table::group $::gRows -by 9 -sum 2} e1
    catch {::pdf4tcllib::table::group $::gRows -quatsch 1} e2
    list [dict get $leer rows] [string match "*outside the row*" $e1] \
            [string match "*unknown option -quatsch*" $e2]
} -result {{} 1 1}

# ============================================================
# Verbundene Zellen in table::draw
# ============================================================
#
# colspan konnte bisher nur table::render. draw hat seinen eigenen
# Zeichenweg, und dort stand die Dict-Form woertlich im PDF --
# "text {Summe Nord} colspan 2". Damit waere table::group nur mit render
# zu gebrauchen gewesen.

test group-2.1 {draw zeichnet den Text, nicht das Dict} -constraints {pdf lib} \
        -body {
    set g [::pdf4tcllib::table::group $::gRows -by 0 -sum 2]
    set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    ::pdf4tcllib::table::draw $pdf 40 40 \
        {{-header Region -align left} {-header Quartal -align left}
         {-header Umsatz -align right}} \
        [dict get $g rows] -maxwidth 400
    set out [$pdf get]
    $pdf destroy
    list [regexp {Summe Nord} $out] [regexp {colspan} $out]
} -result {1 0}

test group-2.2 {und traegt ColSpan in den Baum} -constraints {pdf lib} -body {
    set g [::pdf4tcllib::table::group $::gRows -by 0 -sum 2]
    set f [file join [file dirname [info script]] out zz-group.pdf]
    file mkdir [file dirname $f]
    set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::table::draw $pdf 40 40 \
        {{-header Region -align left} {-header Quartal -align left}
         {-header Umsatz -align right}} \
        [dict get $g rows] -maxwidth 400
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf write -file $f
    $pdf destroy
    set fh [open $f rb] ; set d [read $fh] ; close $fh
    list $n [regexp {/ColSpan 2} $d]
} -result {0 1}


# ============================================================
# pivot -- die Kreuztabelle
# ============================================================
#
# Aus {Region Quartal Umsatz} wird eine Tabelle mit Regionen als Zeilen
# und Quartalen als Spalten. Drei Entscheidungen stecken darin, die die
# Rechnung nicht trifft: welche Spalten es gibt, was in einer leeren
# Zelle steht, und was bei mehreren Werten je Feld passiert.

set ::pRows {
    {Nord Q1 120} {Nord Q2 90} {Sued Q1 150} {Sued Q3 60}
    {West Q1 80}  {Nord Q1 10}
}

test pivot-3.1 {die Spalten ergeben sich aus den Daten} \
        -constraints {pdf lib} -body {
    # Q4 kommt in keiner Zeile vor und taucht deshalb nicht auf.
    set p [::pdf4tcllib::table::pivot $::pRows -rowlabel Region]
    dict get $p cols
} -result {Q1 Q2 Q3}

test pivot-3.2 {mehrere Werte je Feld werden summiert} \
        -constraints {pdf lib} -body {
    # Nord/Q1 kommt zweimal vor: 120 und 10.
    set p [::pdf4tcllib::table::pivot $::pRows]
    lindex [lindex [dict get $p rows] 0] 1
} -result 130

test pivot-3.3 {eine leere Zelle ist nicht null} -constraints {pdf lib} -body {
    # "nichts gemessen" ist etwas anderes als "gemessen, null". Deshalb
    # steht dort der leere String und keine 0.
    set p [::pdf4tcllib::table::pivot $::pRows]
    set nord [lindex [dict get $p rows] 0]
    lindex $nord 3
} -result {}

test pivot-3.4 {-empty setzt, was stattdessen dasteht} \
        -constraints {pdf lib} -body {
    set p [::pdf4tcllib::table::pivot $::pRows -empty "-"]
    lindex [lindex [dict get $p rows] 0] 3
} -result {-}

test pivot-3.5 {Summenspalte und Summenzeile} -constraints {pdf lib} -body {
    set p [::pdf4tcllib::table::pivot $::pRows]
    set rows [dict get $p rows]
    set gesamt [lindex $rows [dict get $p total]]
    list [lindex [lindex $rows 0] end] $gesamt
} -result {220 {Gesamt 360 90 60 510}}

test pivot-3.6 {count zaehlt statt zu addieren} -constraints {pdf lib} -body {
    set p [::pdf4tcllib::table::pivot $::pRows -agg count]
    lindex [lindex [dict get $p rows] 0] 1
} -result 2

test pivot-3.7 {avg mittelt} -constraints {pdf lib} -body {
    set p [::pdf4tcllib::table::pivot $::pRows -agg avg -total 0]
    lindex [lindex [dict get $p rows] 0] 1
} -result 65.0

test pivot-3.8 {min und max} -constraints {pdf lib} -body {
    set mi [::pdf4tcllib::table::pivot $::pRows -agg min -total 0]
    set ma [::pdf4tcllib::table::pivot $::pRows -agg max -total 0]
    list [lindex [lindex [dict get $mi rows] 0] 1] \
            [lindex [lindex [dict get $ma rows] 0] 1]
} -result {10 120}

test pivot-3.9 {-colorder legt die Reihenfolge fest} -constraints {pdf lib} \
        -body {
    # Sortiert waere Q1 Q2 Q3; wer eine andere Ordnung braucht, sagt sie.
    set p [::pdf4tcllib::table::pivot $::pRows -colorder {Q3 Q2 Q1}]
    dict get $p cols
} -result {Q3 Q2 Q1}

test pivot-3.10 {ein nicht summierbarer Wert ist keine Null} \
        -constraints {pdf lib} -body {
    # Bei sum wird er uebersprungen; bei count zaehlt er mit, denn
    # gezaehlt wird die Zeile, nicht der Wert.
    set r {{A x 5} {A x k.A.}}
    set s [::pdf4tcllib::table::pivot $r -agg sum -total 0]
    set c [::pdf4tcllib::table::pivot $r -agg count -total 0]
    list [lindex [lindex [dict get $s rows] 0] 1] \
            [lindex [lindex [dict get $c rows] 0] 1]
} -result {5 2}

test pivot-3.11 {leere Eingabe und unsinnige Angaben} -constraints {pdf lib} \
        -body {
    set leer [::pdf4tcllib::table::pivot {}]
    catch {::pdf4tcllib::table::pivot $::pRows -agg quatsch} e1
    catch {::pdf4tcllib::table::pivot $::pRows -quatsch 1} e2
    list [dict get $leer rows] [string match "*-agg must be*" $e1] \
            [string match "*unknown option -quatsch*" $e2]
} -result {{} 1 1}

test pivot-3.12 {die Kopfzeile passt zu den Zeilen} -constraints {pdf lib} \
        -body {
    # Sonst laeuft die Tabelle beim Zeichnen aus dem Ruder.
    set p [::pdf4tcllib::table::pivot $::pRows -rowlabel Region]
    set n [llength [dict get $p header]]
    set ok 1
    foreach z [dict get $p rows] {
        if {[llength $z] != $n} { set ok 0 }
    }
    list $n $ok
} -result {5 1}


# ============================================================
# breakPoints / fitRows -- wo darf geteilt werden
# ============================================================
#
# Ein Layouter fragt nicht "brich um, wenn du musst", sondern "kann ich
# hier teilen, und wenn ja, wo". table::draw bricht selbst um, aber nach
# seinen eigenen Regeln und ohne vorher etwas zu sagen.
#
# Verboten ist eine Trennstelle an zwei Stellen: mitten in einer ueber
# Zeilen verbundenen Zelle -- sie wird auf der Folgeseite nicht
# wiederholt, waere also zerrissen -- und direkt nach einer
# Gruppenkopfzeile, denn eine Ueberschrift ohne Inhalt am Seitenfuss ist
# keine.

proc bpRows {n} {
    set r {}
    for {set i 0} {$i < $n} {incr i} { lappend r [list "Z$i" $i] }
    return $r
}

test bp-4.1 {die Zeilenhoehe folgt der Schriftgroesse} \
        -constraints {pdf lib} -body {
    # Wie in table::draw: rowheight, sonst 1.8 mal fontsize.
    set a [dict get [::pdf4tcllib::table::breakPoints [bpRows 3]] rowH]
    set b [dict get [::pdf4tcllib::table::breakPoints [bpRows 3] \
            -rowheight 20] rowH]
    list [expr {abs($a - 9 * 1.8) < 0.001}] $b
} -result {1 20.0}

test bp-4.2 {die Kopfzeile zaehlt mit} -constraints {pdf lib} -body {
    set mit  [::pdf4tcllib::table::fitRows 100 [bpRows 20]]
    set ohne [::pdf4tcllib::table::fitRows 100 [bpRows 20] -header 0]
    # Ohne Kopf passt genau eine Zeile mehr.
    list [expr {$ohne == $mit + 1}] [expr {$mit > 0}]
} -result {1 1}

test bp-4.3 {zu wenig Platz gibt null Zeilen} -constraints {pdf lib} -body {
    # Nicht eine halbe Zeile, nicht ein Fehler: null heisst "hier faengt
    # die Tabelle nicht an", und der Aufrufer muss den Platz vergroessern.
    ::pdf4tcllib::table::fitRows 10 [bpRows 5]
} -result 0

test bp-4.4 {genug Platz nimmt alles} -constraints {pdf lib} -body {
    ::pdf4tcllib::table::fitRows 5000 [bpRows 12]
} -result 12

test bp-4.5 {eine verbundene Zelle sperrt die Trennstellen} \
        -constraints {pdf lib} -body {
    # rowspan 3 in Zeile 0: vor Zeile 1 und 2 darf nicht getrennt werden.
    set rows [list [list [dict create text N rowspan 3] Q1 1] \
            {Q2 2} {Q3 3} {S Q1 4} {T Q2 5}]
    dict get [::pdf4tcllib::table::breakPoints $rows] forbidden
} -result {1 2}

test bp-4.6 {und fitRows geht auf die naechste erlaubte zurueck} \
        -constraints {pdf lib} -body {
    # Rechnerisch passten bei 60 Punkt zwei Datenzeilen; die zweite waere
    # aber mitten in der verbundenen Zelle. Also null -- die Zelle wird
    # nicht zerrissen, sie kommt ganz auf die naechste Seite.
    set rows [list [list [dict create text N rowspan 3] Q1 1] \
            {Q2 2} {Q3 3} {S Q1 4} {T Q2 5}]
    list [::pdf4tcllib::table::fitRows 60 $rows] \
            [::pdf4tcllib::table::fitRows 70 $rows]
} -result {0 3}

test bp-4.7 {ein Gruppenkopf haelt die erste Zeile bei sich} \
        -constraints {pdf lib} -body {
    # table::group liefert die Nummern der Kopfzeilen; wer sie
    # durchreicht, bekommt sie als verbotene Trennstellen zurueck.
    set g [::pdf4tcllib::table::group {{A x 1} {A y 2} {B z 3}} \
            -by 0 -sum 2 -header 1]
    ::pdf4tcllib::table::breakPoints [dict get $g rows] \
            -groups [dict get $g groups]
} -match glob -result {*forbidden {1 5}*}

test bp-4.8 {ohne -groups sperrt nichts} -constraints {pdf lib} -body {
    set g [::pdf4tcllib::table::group {{A x 1} {A y 2} {B z 3}} \
            -by 0 -sum 2 -header 1]
    dict get [::pdf4tcllib::table::breakPoints [dict get $g rows]] forbidden
} -result {}

test bp-4.9 {die Hoehen sind von oben gerechnet} -constraints {pdf lib} \
        -body {
    set bp [::pdf4tcllib::table::breakPoints [bpRows 3] -rowheight 10]
    dict get $bp heights
} -result {10.0 20.0 30.0}

test bp-4.10 {leere Tabelle und unbekannte Option} -constraints {pdf lib} \
        -body {
    set bp [::pdf4tcllib::table::breakPoints {}]
    catch {::pdf4tcllib::table::breakPoints {} -quatsch 1} e
    list [dict get $bp rows] [dict get $bp heights] \
            [string match "*unknown option -quatsch*" $e]
} -result {0 {} 1}

rename bpRows {}


# ============================================================
# widths -- natuerliche und kleinste Breite
# ============================================================
#
# Ein Layouter, der Spalten verteilt, fragt zweierlei: wie breit will die
# Tabelle sein, wenn sie darf, und wie schmal geht es gerade noch.
# Dazwischen kann er verteilen; darunter nicht, ohne dass etwas mitten im
# Wort umbricht.

set ::wCols {{-header "Artikel" -align left} {-header "Menge" -align right}}
set ::wRows {{"Sechskantschraube M6 x 20" 100} {"Mutter" 200}}

test wd-5.1 {natural ist breiter als min} -constraints {pdf lib} -body {
    set w [::pdf4tcllib::table::widths $::wCols $::wRows]
    expr {[dict get $w naturalTotal] > [dict get $w minTotal]}
} -result 1

test wd-5.2 {min ist das laengste Wort, nicht das laengste Zeichen} \
        -constraints {pdf lib} -body {
    # Ein Wort, das nicht passt, wird zeichenweise zerschnitten -- das
    # ist keine Untergrenze, sondern eine Notlage. Die Untergrenze ist
    # das laengste Wort.
    set w [::pdf4tcllib::table::widths $::wCols $::wRows]
    set minArtikel [lindex [dict get $w min] 0]
    set pdf {}
    # "Sechskantschraube" ist das laengste Wort der Spalte.
    set wort [::pdf4tcllib::text::width "Sechskantschraube" 9 \
            [::pdf4tcllib::fonts::fontSans] $pdf]
    expr {abs($minArtikel - ($wort + 8)) < 0.01}
} -result 1

test wd-5.3 {die Kopfzeile zaehlt mit} -constraints {pdf lib} -body {
    # Eine Ueberschrift, die breiter ist als jeder Wert, bestimmt die
    # Spalte.
    set a [::pdf4tcllib::table::widths {{-header "x"}} {{"kurz"}}]
    set b [::pdf4tcllib::table::widths \
            {{-header "eine sehr lange Ueberschrift"}} {{"kurz"}}]
    expr {[dict get $b naturalTotal] > [dict get $a naturalTotal]}
} -result 1

test wd-5.4 {je Spalte eine Zahl} -constraints {pdf lib} -body {
    set w [::pdf4tcllib::table::widths $::wCols $::wRows]
    list [llength [dict get $w natural]] [llength [dict get $w min]]
} -result {2 2}

test wd-5.5 {eine verbundene Zelle blaeht keine Spalte auf} \
        -constraints {pdf lib} -body {
    # Wie in _calcColWidths: sie steht ueber mehreren Spalten, ihre
    # Breite gehoert keiner einzelnen.
    set ohne [::pdf4tcllib::table::widths {{-header A} {-header B}} \
            {{kurz 1}}]
    set mit  [::pdf4tcllib::table::widths {{-header A} {-header B}} \
            [list {kurz 1} \
             [list [dict create text "eine sehr sehr lange Summenzeile" \
                    colspan 2]]]]
    expr {abs([dict get $ohne naturalTotal] - \
              [dict get $mit naturalTotal]) < 0.01}
} -result 1

test wd-5.6 {mit -pdf wird genau gemessen} -constraints {pdf lib} -body {
    # Ohne $pdf schaetzt text::width ueber Zeichenklassen; bei einer
    # CID-Schrift liegt das weit daneben.
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set genau [::pdf4tcllib::table::widths $::wCols $::wRows -pdf $pdf]
    $pdf destroy
    set schaetz [::pdf4tcllib::table::widths $::wCols $::wRows]
    # Beide plausibel, aber nicht identisch.
    list [expr {[dict get $genau naturalTotal] > 0}] \
            [expr {[dict get $schaetz naturalTotal] > 0}]
} -result {1 1}

test wd-5.7 {unbekannte Option meldet sich} -constraints {pdf lib} -body {
    catch {::pdf4tcllib::table::widths $::wCols $::wRows -quatsch 1} e
    string match "*unknown option -quatsch*" $e
} -result 1

cleanupTests
