# test_consistency.tcl -- Prozeduren, die miteinander uebereinstimmen muessen
#
# WARUM ES DIESE DATEI GIBT
#
# Am 29.08.2026 wurde U+00AD an einem Tag dreimal verschieden behandelt,
# eine Ebene tiefer in pdf4tcl: drawTextBox liess es weg, getStringWidth
# zaehlte es mit, text druckte es. Jede Stelle war fuer sich richtig und
# hatte gruene Tests. Niemand pruefte, dass sie miteinander
# uebereinstimmen.
#
# pdf4tcllib hat dieselbe Lage an mehreren Stellen: mehrere Prozeduren
# beantworten dieselbe Frage auf verschiedenen Wegen.
#
#     text::width          gegen  $pdf getStringWidth
#     measure::block       gegen  den echten Zeichenlauf
#     table::fitRows       gegen  das, was table::draw wirklich umbricht
#     table::widths        gegen  die Breite, die draw wirklich braucht
#     text::wrap           gegen  drawTextBox
#
# Alle fuenf stimmen heute. Das ist keine Selbstverstaendlichkeit,
# sondern der Zustand, den diese Datei festhaelt: sobald einer der Wege
# geaendert wird und der andere nicht, wird es hier rot -- und nicht erst
# auf Papier.
#
# WAS DIESE DATEI NICHT PRUEFT
#
# Ob die Antwort RICHTIG ist. Faellt eine Eigenschaft ganz weg, stimmen
# alle Wege wieder ueberein -- falsch, aber einig. Dafuer sind die
# uebrigen Testdateien da. Die zwei Sorten ersetzen einander nicht:
#
#     diese Datei    sagen sie DASSELBE?
#     die anderen    sagen sie das RICHTIGE?
#
# GEGENPROBE -- jedes Paar wurde einzeln kaputtgemacht:
#
#     text::width ignoriert das pdf-Objekt        kon-1.1
#     fitRows rechnet mit falschem Kopf           kon-3.1
#     measure::block meldet 5 pt zu wenig         kon-2.1
#     wrap trennt nicht mehr am Bindestrich       kon-5.1, kon-5.2
#     widths meldet zu wenig                      kon-4.1
#
# Bei zwei Anlaeufen griff die Gegenprobe zuerst NICHT -- der Patch traf
# den Code nicht, und der Lauf blieb gruen. Eine Gegenprobe, die nicht
# greift, ist selbst ungeprueft; sie sagt Ruhe, wo keine ist. Deshalb
# steht hier, welcher Eingriff welchen Test faellt: wer die Liste
# nachvollzieht, prueft die Pruefung.

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

proc konNeu {{size 10}} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    $pdf setFont $size [::pdf4tcllib::fonts::fontSans]
    return $pdf
}

# Material, das historisch schiefgegangen ist.
set ::konTexte {
    "Silben"
    "Sil\u00ADben"
    "Donau-dampf"
    "Der Betrag -5 Euro"
    "AVAV"
    "Umlaute \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df"
    "Euro 100\u20ac"
}

# ---------------------------------------------------------------------
# Paar 1: text::width gegen getStringWidth
#
# Zwei Wege zur selben Breite. text::width kann ohne pdf-Objekt nur
# schaetzen -- MIT Objekt muss es dasselbe sagen wie pdf4tcl selbst,
# sonst bricht jeder Umbruch dieser Bibliothek an einer anderen Stelle
# als pdf4tcl es taete.
# ---------------------------------------------------------------------

test kon-1.1 {text::width mit pdf-Objekt ist getStringWidth} \
        -constraints {pdf lib} -body {
    set pdf [konNeu]
    set f [::pdf4tcllib::fonts::fontSans]
    set fehler {}
    foreach t $::konTexte {
        set a [::pdf4tcllib::text::width $t 10 $f $pdf]
        set b [$pdf getStringWidth $t]
        if {abs($a - $b) > 0.001} {
            lappend fehler [format "%s: width %.2f, getStringWidth %.2f" \
                    [string map [list \u00AD <AD>] $t] $a $b]
        }
    }
    $pdf destroy
    set fehler
} -result {}

test kon-1.2 {ohne pdf-Objekt ist es eine Schaetzung, und das darf man sehen} \
        -constraints {pdf lib} -body {
    # Die Schaetzung DARF abweichen -- sie kennt die Schrift nicht.
    # Geprueft wird nur, dass sie ueberhaupt etwas liefert und nicht
    # heimlich dasselbe behauptet.
    set pdf [konNeu]
    set f [::pdf4tcllib::fonts::fontSans]
    set txt "w35 Mo 17.08.26 CC Sped1"
    set geschaetzt [::pdf4tcllib::text::width $txt 8 $f]
    set genau      [::pdf4tcllib::text::width $txt 8 $f $pdf]
    $pdf destroy
    list [expr {$geschaetzt > 0}] [expr {$genau > 0}]
} -result {1 1}

# ---------------------------------------------------------------------
# Paar 2: measure::block gegen den echten Zeichenlauf
#
# measure::block existiert, damit ein Aufrufer VOR dem Zeichnen weiss,
# wie hoch etwas wird. Weicht es ab, reserviert er den falschen Platz --
# und merkt es auf Papier.
# ---------------------------------------------------------------------

test kon-2.1 {measure::block misst, was der echte Lauf braucht} \
        -constraints {pdf lib} -body {
    set cols {{-header A -align left} {-header B -align right}}
    set fehler {}
    foreach n {3 12 40 80} {
        set rows {}
        for {set i 0} {$i < $n} {incr i} { lappend rows [list "Zeile $i" $i] }

        set m [::pdf4tcllib::measure::block mp {
            ::pdf4tcllib::table::draw $mp 40 40 $cols $rows -maxwidth 400
        } -paper a4 -y 40]

        set pdf [konNeu]
        set yEnd [::pdf4tcllib::table::draw $pdf 40 40 $cols $rows -maxwidth 400]
        $pdf destroy

        set echt [expr {$yEnd - 40}]
        if {abs([dict get $m height] - $echt) > 0.01} {
            lappend fehler [format "%d Zeilen: gemessen %.2f, echt %.2f" \
                    $n [dict get $m height] $echt]
        }
    }
    set fehler
} -result {}

test kon-2.2 {measure::block zeichnet nicht ins echte Dokument} \
        -constraints {pdf lib} -body {
    # Der Wegwerf-Grundsatz: waere es anders, stuende der Messlauf im
    # fertigen PDF. Genau deshalb heisst die Variable im Skript $mp und
    # nicht $pdf.
    set pdf [konNeu]
    ::pdf4tcllib::measure::block mp {
        ::pdf4tcllib::table::draw $mp 40 40 {{-header A}} {{eins}} -maxwidth 200
    } -paper a4 -y 40
    set out [$pdf get]
    $pdf destroy
    regexp -all {\(eins\) Tj} $out
} -result 0

# ---------------------------------------------------------------------
# Paar 3: table::fitRows gegen den wirklichen Seitenumbruch
#
# fitRows sagt, wieviele Zeilen auf eine Seite passen. draw entscheidet
# es dann selbst. Sind die beiden verschiedener Meinung, plant ein
# Layouter falsch -- und die Tabelle bricht woanders als versprochen.
# ---------------------------------------------------------------------

test kon-3.1 {fitRows sagt, was draw wirklich auf die erste Seite setzt} \
        -constraints {pdf lib} -body {
    set ctx [::pdf4tcllib::page::context a4]
    set cols {{-header A -align left}}
    set rows {}
    for {set i 0} {$i < 100} {incr i} { lappend rows [list "Zeile $i"] }

    set vorhergesagt [::pdf4tcllib::table::fitRows \
            [dict get $ctx SH] $rows -fontsize 9]

    set pdf [konNeu 9]
    ::pdf4tcllib::table::draw $pdf [dict get $ctx SX] [dict get $ctx SY] \
            $cols $rows -maxwidth 400 -ctx $ctx -fontsize 9
    set out [$pdf get]
    $pdf destroy

    # Der Strom je Seite: das erste Seitenobjekt endet, wo das zweite
    # beginnt. Gezaehlt wird ueber die Textbefehle davor.
    set seiten [split $out "\f"]
    set aufSeite1 [regexp -all {\(Zeile [0-9]+\) Tj} [lindex $seiten 0]]

    list $vorhergesagt $aufSeite1 \
            [expr {$vorhergesagt == $aufSeite1 ? "gleich" : "VERSCHIEDEN"}]
} -match glob -result "* * gleich"

test kon-3.2 {passt alles auf eine Seite, sagt fitRows genau das} \
        -constraints {pdf lib} -body {
    set ctx [::pdf4tcllib::page::context a4]
    set rows {}
    for {set i 0} {$i < 10} {incr i} { lappend rows [list "Zeile $i"] }
    ::pdf4tcllib::table::fitRows [dict get $ctx SH] $rows -fontsize 9
} -result 10

# ---------------------------------------------------------------------
# Paar 4: table::widths gegen die Breite, die draw wirklich braucht
#
# widths sagt, wie breit eine Tabelle sein will. Zeichnet man sie in
# genau dieser Breite, darf nichts gekuerzt werden.
# ---------------------------------------------------------------------

test kon-4.1 {in der natuerlichen Breite wird nichts gekuerzt} \
        -constraints {pdf lib} -body {
    set cols {{-header "Artikel" -align left} {-header "Menge" -align right}}
    set rows {
        {"Sechskantschraube M6 x 20" 100}
        {"Mutter" 200}
    }
    set pdf [konNeu 9]
    set w [::pdf4tcllib::table::widths $cols $rows -pdf $pdf -fontsize 9]
    ::pdf4tcllib::table::draw $pdf 40 40 $cols $rows \
            -maxwidth [dict get $w naturalTotal] -fontsize 9
    set out [$pdf get]
    $pdf destroy
    # Gekuerzt wird mit "..." -- in der natuerlichen Breite darf das
    # nicht vorkommen.
    regexp -all {\.\.\.} $out
} -result 0

test kon-4.2 {unter der kleinsten Breite wird gekuerzt} -constraints {pdf lib} \
        -body {
    # Die Gegenrichtung: min ist eine Untergrenze, keine Zierde. Darunter
    # muss etwas verlorengehen, sonst sagt widths etwas Falsches.
    set cols {{-header "Artikel" -align left}}
    set rows {{"Sechskantschraube M6 x 20"}}
    set pdf [konNeu 9]
    set w [::pdf4tcllib::table::widths $cols $rows -pdf $pdf -fontsize 9]
    set eng [expr {[dict get $w minTotal] * 0.5}]
    ::pdf4tcllib::table::draw $pdf 40 40 $cols $rows -maxwidth $eng -fontsize 9
    set out [$pdf get]
    $pdf destroy
    expr {[regexp {\.\.\.} $out] ? 1 : 0}
} -result 1

# ---------------------------------------------------------------------
# Paar 5: text::wrap gegen drawTextBox
#
# Beide brechen Text um. Die Bibliothek benutzt wrap, pdf4tcl benutzt
# seine eigene Logik. Seit 0.9.4.60 gilt dieselbe Bindestrichregel in
# beiden -- das war eine bewusste Vereinheitlichung und soll es bleiben.
# ---------------------------------------------------------------------

test kon-5.1 {wrap und drawTextBox brechen an denselben Stellen} \
        -constraints {pdf lib} -body {
    set f [::pdf4tcllib::fonts::fontSans]
    set fehler {}
    foreach txt {"Silben trennung ist eine Sache"
                 "Donau-dampfschiff faehrt"
                 "Der Betrag -5 Euro ist klein"} {
        foreach breite {60 100 160 300} {
            set a [konNeu 10]
            set nWrap [llength [::pdf4tcllib::text::wrap $txt $breite 10 $f 0 $a]]
            $a drawTextBox 0 20 $breite 300 $txt -linesvar nBox
            $a destroy
            if {$nWrap != $nBox} {
                lappend fehler [format "%s bei %d: wrap %d, drawTextBox %d" \
                        $txt $breite $nWrap $nBox]
            }
        }
    }
    set fehler
} -result {}

test kon-5.2 {die Bindestrichregel gilt in beiden} -constraints {pdf lib} \
        -body {
    # Ein Strich zwischen zwei Zeichen trennt, ein Vorzeichen nicht.
    # Stimmten die beiden hier nicht ueberein, brauche eine Tabelle
    # woanders um als ein Absatz mit demselben Text.
    set f [::pdf4tcllib::fonts::fontSans]
    set pdf [konNeu 10]
    set a [llength [::pdf4tcllib::text::wrap "Donau-dampf" 40 10 $f 0 $pdf]]
    $pdf drawTextBox 0 20 40 200 "Donau-dampf" -linesvar b
    set c [llength [::pdf4tcllib::text::wrap "Betrag -5" 40 10 $f 0 $pdf]]
    $pdf drawTextBox 0 100 40 200 "Betrag -5" -linesvar d
    $pdf destroy
    list [expr {$a == $b}] [expr {$c == $d}]
} -result {1 1}

# ---------------------------------------------------------------------
# Paar 6: measure::block unter ANDEREN Bedingungen als der echte Lauf
#
# Paar 2 vergleicht die beiden unter gleichen Bedingungen. Das ist die
# halbe Frage. Das Wegwerf-Dokument faengt naemlich frisch an --
# Vorgabeschrift, Vorgabe-Zeilenabstand, kein Kerning, -margin 0. Das
# echte Dokument, in das der Aufrufer nachher zeichnet, tut das nicht.
#
# Ein Baustein, der den AKTUELLEN Zustand des Dokuments benutzt statt
# seine Schrift selbst zu setzen, wuerde deshalb anders gemessen als
# gezeichnet -- und zwar lautlos, weil beide Wege fuer sich stimmen.
#
# Gemessen am 2026-08-29: table::draw und text::writeParagraph benutzen
# den Zustand nicht. Die vier Tests sind gruen, und DAS ist ihre
# Aussage. Faengt ein Baustein an, den Zustand zu lesen, wird hier rot.
#
# Jede Bedingung einzeln, damit die Meldung sagt, welche es war.
# ---------------------------------------------------------------------

# Zeichnet den Block einmal wirklich, unter den angegebenen Bedingungen.
# $vorbereitung und $script sehen das Dokument als @PDF@.
proc konEcht {vorbereitung script args} {
    set pdf [::pdf4tcl::new %AUTO% -orient 1 -compress 0 {*}$args]
    $pdf startPage
    if {$vorbereitung ne ""} {
        uplevel 1 [string map [list @PDF@ $pdf] $vorbereitung]
    }
    set y [uplevel 1 [string map [list @PDF@ $pdf] $script]]
    set seiten 1
    catch {set seiten [$pdf pageCount]}
    $pdf destroy
    return [list $y $seiten]
}

set ::konAbsatz "Ein laengerer Absatz zum Umbrechen und Messen der Hoehe,\
        mit genug Woertern."

test kon-6.1 {eine gesetzte Schrift im echten Dokument aendert die Hoehe nicht} \
        -constraints {pdf lib} -body {
    set h [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::text::writeParagraph $mp $::konAbsatz 0 0 200
    } -paper a4]
    lassign [konEcht {@PDF@ setFont 20 Helvetica} {
        ::pdf4tcllib::text::writeParagraph @PDF@ $::konAbsatz 0 0 200
    } -paper a4] y seiten
    expr {abs($h - $y) < 0.01}
} -result 1

test kon-6.2 {ein gesetzter Zeilenabstand aendert die Hoehe nicht} \
        -constraints {pdf lib} -body {
    set h [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::text::writeParagraph $mp $::konAbsatz 0 0 200
    } -paper a4]
    lassign [konEcht {@PDF@ setLineSpacing 2.0} {
        ::pdf4tcllib::text::writeParagraph @PDF@ $::konAbsatz 0 0 200
    } -paper a4] y seiten
    expr {abs($h - $y) < 0.01}
} -result 1

test kon-6.3 {eingeschaltetes Kerning aendert die Hoehe nicht} \
        -constraints {pdf lib} -body {
    set h [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::text::writeParagraph $mp $::konAbsatz 0 0 200
    } -paper a4]
    lassign [konEcht {@PDF@ setKerning 1} {
        ::pdf4tcllib::text::writeParagraph @PDF@ $::konAbsatz 0 0 200
    } -paper a4] y seiten
    expr {abs($h - $y) < 0.01}
} -result 1

test kon-6.4 {ein Rand im echten Dokument aendert die Hoehe nicht} \
        -constraints {pdf lib} -body {
    # -margin steht in measure::block auf 0. Haette table::draw den Rand
    # des Dokuments gelesen, stuende hier eine Abweichung.
    set cols {{-header A -align left} {-header B -align right}}
    set rows {}
    for {set i 0} {$i < 5} {incr i} { lappend rows [list "Zeile $i" $i] }
    set h [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::table::draw $mp 0 0 $cols $rows -maxwidth 300
    } -paper a4]
    lassign [konEcht {} {
        ::pdf4tcllib::table::draw @PDF@ 0 0 $cols $rows -maxwidth 300
    } -paper a4 -margin 50] y seiten
    expr {abs($h - $y) < 0.01}
} -result 1

# ---------------------------------------------------------------------
# Was die Paare NICHT finden -- ein Block hoeher als die Seite
#
# Hier ist der Fall, vor dem der Kopf dieser Datei warnt, als Messung:
# measure und der echte Lauf stimmen ueberein, und sie sind beide
# falsch. Kein Vergleich kann das finden, weil beide Seiten denselben
# Weg gehen. Deshalb stehen die drei Tests hier als ausdrueckliche
# Behauptung ueber den Ist-Zustand.
#
# Gemessen am 2026-08-29, ein Absatz mit 30 Wiederholungen auf a4
# (841,89 pt hoch), Spaltenbreite 200 pt:
#
#     measure::height           1207.00
#     echter Lauf, y            1207.00      einig
#     measure pages                    1
#     echter Lauf, pageCount           1
#     measure::fits 1300               1      "ja, passt"
#
# Im Inhaltsstrom stehen 71 Textzeilen, die erste bei y=832.7, die
# LETZTE bei y=-7.3 -- unter dem Blatt. Eine Zeile, ein Wort.
#
# Und beide Pruefwerkzeuge sehen es nicht:
#
#     geometry-check   0 Befunde. Es sieht Gezeichnetes, keinen Text --
#                      steht so in seinem Kopf, ist also kein Defekt.
#                      Aber die dortige Zusage "die zwei zusammen decken
#                      die Seite ab" stimmt an dieser Stelle nicht.
#     layout-check     131 Randbefunde, KEINER davon die verlorene Zeile.
#                      Es liest mit pdftotext, und pdftotext gibt 359 von
#                      360 Woertern heraus: das Wort unter dem Blatt
#                      faellt lautlos weg.
#
# Was daraus folgen sollte, entscheidet der Autor. Zwei Moeglichkeiten:
# fits koennte die Seitenhoehe des Wegwerf-Dokuments kennen und bei
# Ueberlauf "" liefern statt 1; oder writeParagraph koennte am
# Seitenende abbrechen. Beides aendert Verhalten und gehoert in eine
# neue Version -- deshalb steht hier nur der Befund.
# ---------------------------------------------------------------------

test kon-7.1 {ein Block laeuft unter das Blatt, Messung und Lauf sind einig} \
        -constraints {pdf lib} -body {
    set lang [string repeat "$::konAbsatz " 30]
    set m [::pdf4tcllib::measure::block mp {
        ::pdf4tcllib::text::writeParagraph $mp $lang 0 0 200
    } -paper a4]
    lassign [konEcht {} {
        ::pdf4tcllib::text::writeParagraph @PDF@ $lang 0 0 200
    } -paper a4] y seiten
    list [expr {abs([dict get $m height] - $y) < 0.01}] \
         [expr {[dict get $m height] > 841.89}] \
         [dict get $m pages] $seiten
} -result {1 1 1 1}

test kon-7.2 {fits sagt nein, wenn der Block unter das Blatt laeuft} \
        -constraints {pdf lib} -body {
    # Bis 0.6.4 sagte fits hier JA. Es prueft die Hoehe gegen den
    # genannten Platz und die Seitenzahl gegen 1 -- beides traf zu, denn
    # die Seitenzahl steigt nur, wenn der Baustein SELBST umbricht, und
    # writeParagraph tut das nicht. Der Block lief stattdessen unten
    # hinaus, und fits nannte das "passt".
    #
    # measure::block liefert jetzt overflow, und fits liest es.
    set lang [string repeat "$::konAbsatz " 30]
    ::pdf4tcllib::measure::fits 1300 mp {
        ::pdf4tcllib::text::writeParagraph $mp $lang 0 0 200
    } -paper a4
} -result 0

test kon-7.4 {ein Block, der passt, bleibt "passt"} \
        -constraints {pdf lib} -body {
    # Die Gegenprobe: overflow darf nicht alles ablehnen. Ein einzelner
    # Absatz auf a4 laeuft nirgends hinaus.
    ::pdf4tcllib::measure::fits 200 mp {
        ::pdf4tcllib::text::writeParagraph $mp $::konAbsatz 0 0 200
    } -paper a4
} -result 1

test kon-7.5 {block nennt overflow und die Blatthoehe} \
        -constraints {pdf lib} -body {
    set lang [string repeat "$::konAbsatz " 30]
    set m [::pdf4tcllib::measure::block mp {
        ::pdf4tcllib::text::writeParagraph $mp $lang 0 0 200
    } -paper a4]
    set kurz [::pdf4tcllib::measure::block mp {
        ::pdf4tcllib::text::writeParagraph $mp $::konAbsatz 0 0 200
    } -paper a4]
    list [dict get $m overflow] [dict get $kurz overflow] \
         [expr {[dict get $m height] > [dict get $m sheet]}]
} -result {1 0 1}

test kon-7.3 {die letzte Zeile steht wirklich unter dem Blatt} \
        -constraints {pdf lib} -body {
    # Nicht ueber pdftotext gemessen -- das laesst sie weg. Direkt aus
    # dem Inhaltsstrom, deshalb -compress 0 in konEcht.
    set lang [string repeat "$::konAbsatz " 30]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::text::writeParagraph $pdf $lang 0 0 200
    set strom [$pdf get]
    $pdf destroy
    set unter 0
    set gesamt 0
    foreach {all y} [regexp -all -inline \
            {1 0 0 1 [0-9.-]+ (-?[0-9.]+) Tm} $strom] {
        incr gesamt
        if {$y < 0} { incr unter }
    }
    list [expr {$gesamt > 60}] [expr {$unter >= 1}]
} -result {1 1}

rename konNeu {}
rename konEcht {}

cleanupTests
