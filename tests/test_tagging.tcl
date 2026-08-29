# test_tagging.tcl -- der Nachweis, dass die Bausteine vollstaendig taggen
#
# getUntaggedCount sagt, wie viele Zeichenbefehle weder in einem Element
# noch in einem Artefakt stecken. Bei einem Dokument mit `tagged 1` ist
# jede Zahl ausser null ein Loch im Strukturbaum: ein Vorleseprogramm
# ueberspringt den Inhalt, und PDF/UA faellt darueber.
#
# Zwei Tests dieser Art gab es bereits, je einer in test_flow.tcl und
# test_chart.tcl. Was fehlte, ist der Fall, um den es wirklich geht: ein
# Dokument aus MEHREREN Bausteinen. Ein Modul fuer sich kann sauber sein,
# und trotzdem faellt etwas durch, sobald zwei zusammen auf einer Seite
# stehen -- oder sobald jemand einen neuen Zeichenbefehl einbaut und das
# Taggen vergisst.
#
# Der Zaehler ist nicht blind, das prueft tag-0.1: roher Text und ein
# rohes Rechteck auf einem getaggten Dokument ergeben 2.

package require tcltest
namespace import ::tcltest::*

testConstraint pdf    [expr {![catch {package require pdf4tcl}]}]
testConstraint lib    [expr {![catch {package require pdf4tcllib}]}]
testConstraint chart  [expr {![catch {package require pdf4tclchart}]}]
testConstraint toc    [expr {![catch {package require pdf4tcltoc}]}]
testConstraint labels [expr {![catch {package require pdf4tcllabels}]}]
testConstraint forms  [expr {![catch {package require pdf4tclforms}]}]
testConstraint verapdf [expr {[llength [auto_execok verapdf]] > 0}]

catch {::pdf4tcllib::fonts::init}

# Eine eingebettete Schrift ist Voraussetzung fuer jeden PDF/A-Anspruch;
# ohne TrueType im System kann das hier nichts belegen.
testConstraint ttf [expr {
    ![catch {set ::pdf4tcllib::fonts::hasTtf} v] && $v}]

proc tagOut {name} {
    set d [file join [file dirname [info script]] out]
    file mkdir $d
    return [file join $d $name]
}

# Ein getaggtes Dokument mit offener Seite.
proc tagNew {args} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 {*}$args]
    $pdf tagged 1
    $pdf startPage
    return $pdf
}

# ============================================================
# Gegenprobe: zaehlt der Zaehler ueberhaupt?
# ============================================================

test tag-0.1 {roh gezeichnet wird gezaehlt} -constraints {pdf} -body {
    # Ohne diesen Test waere jede Null unten wertlos: sie koennte auch
    # heissen, dass gar nichts gezeichnet wurde.
    set pdf [tagNew]
    $pdf setFont 12 Helvetica
    $pdf text "ungetaggt" -x 50 -y 700
    $pdf rectangle 50 600 100 50
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 2

# ============================================================
# Die Bausteine einzeln
# ============================================================

test tag-1.1 {text::writeParagraph} -constraints {pdf lib} -body {
    set pdf [tagNew]
    ::pdf4tcllib::text::writeParagraph $pdf "Ein Absatz Text." 50 700 300
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

test tag-1.2 {table::render mit Kopfzeile} -constraints {pdf lib} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf tagged 1
    $pdf startPage
    set y 40.0
    set pno 1
    set rows {}
    for {set i 0} {$i < 5} {incr i} {
        lappend rows [list "Zeile$i" "Wert-$i" [expr {$i * 7}]]
    }
    set td [dict create header {Schluessel Wert Zahl} rows $rows \
            aligns {left left right}]
    ::pdf4tcllib::table::render $pdf $td 40.0 y 515.0 40.0 700.0 pno \
            595.0 842.0 40.0 9 12
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

test tag-1.3 {chart::bar und chart::pie} -constraints {pdf chart} -body {
    set pdf [tagNew]
    ::pdf4tcllib::chart::bar $pdf 60 60 460 200 {A 1 B 2} -title "Titel"
    ::pdf4tcllib::chart::pie $pdf 60 300 460 200 {A 1 B 2} -legend 1
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

test tag-1.4 {toc::heading} -constraints {pdf toc} -body {
    set pdf [tagNew]
    set ctx [::pdf4tcllib::page::context a4]
    set y 60.0
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Kapitel"
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

test tag-1.5 {labels::render, auch was der Rueckruf zeichnet} \
        -constraints {pdf labels} -body {
    # Der Rueckruf zeichnet hier absichtlich ROH -- kein tag::begin, kein
    # Artefakt. Etikettenrahmen und -text sind Zierrat; render muss sie
    # als Artefakt fassen, sonst zaehlt jeder Aufkleber mit.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::labels::render $pdf 3474 {Alpha Beta Gamma} \
            {x y w h rec} {
        $pdf setFont 8 Helvetica
        $pdf text $rec -x [expr {$x + 4}] -y [expr {$y + 12}]
        $pdf rectangle $x $y $w $h
    }
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

test tag-1.6 {forms: Textfeld und Checkbox} -constraints {pdf forms} -body {
    set pdf [tagNew]
    set ctx [::pdf4tcllib::page::context a4]
    set y 100
    ::pdf4tcllib::forms::field $pdf $ctx y {type text label "Name" id f_n}
    ::pdf4tcllib::forms::checkboxLine $pdf $ctx y \
            {label "Einverstanden" id f_ok}
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

# ============================================================
# Alles zusammen auf einer Seite -- der eigentliche Nachweis
# ============================================================

test tag-2.1 {ein Dokument aus mehreren Bausteinen} \
        -constraints {pdf lib chart toc forms} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf tagged 1
    $pdf startPage
    set ctx [::pdf4tcllib::page::context a4]

    set y 40.0
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Bericht"
    ::pdf4tcllib::text::writeParagraph $pdf \
            "Der Bericht fasst die Zahlen des Quartals zusammen." \
            40 [expr {$y + 20}] 500

    set y 160.0
    set pno 1
    set rows {{Nord 120} {Sued 90} {West 150}}
    set td [dict create header {Region Umsatz} rows $rows \
            aligns {left right}]
    ::pdf4tcllib::table::render $pdf $td 40.0 y 515.0 160.0 400.0 pno \
            595.0 842.0 40.0 9 12

    ::pdf4tcllib::chart::bar $pdf 40 450 500 200 {Nord 120 Sued 90 West 150} \
            -title "Umsatz je Region"

    set y 680.0
    ::pdf4tcllib::forms::checkboxLine $pdf $ctx y \
            {label "geprueft" id f_geprueft}

    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf write -file [tagOut zz-tagging.pdf]
    $pdf destroy
    set n
} -result 0

test tag-2.2 {und dasselbe ueber zwei Seiten} \
        -constraints {pdf lib chart} -body {
    # Ein Seitenwechsel setzt den Strukturbaum fort; wenn dabei etwas
    # verlorengeht, faellt es nur hier auf.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::text::writeParagraph $pdf "Seite eins." 40 60 500
    $pdf endPage
    $pdf startPage
    ::pdf4tcllib::chart::pie $pdf 40 100 400 200 {A 1 B 2} -legend 1
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

# ============================================================
# PDF/A mit einer Checkbox -- der Fall, den kein Beispiel abdeckte
# ============================================================
#
# Bis pdf4tcl 0.9.4.55 machte eine einzige Checkbox ein PDF/A-Dokument
# unkonform: ZapfDingbats hat kein einbettbares Fontprogramm. Seit .55
# zeichnet der Kern die Marke mit Linien, sobald ein Anspruch erhoben ist.
#
# Die Beschriftung daneben blieb ein zweites Loch: forms las
# CFG(fontFamily) unmittelbar, und dort steht Helvetica -- ebenfalls ohne
# einbettbares Programm. Gemessen vor der Korrektur in forms::_cfg: eine
# Warnung und veraPDF FAIL 2b.

test tag-3.1 {eine Checkbox loest keine PDF/A-Warnung mehr aus} \
        -constraints {pdf forms ttf} -body {
    set ::pdf4tcl::warnings {}
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -pdfa 2b]
    $pdf startPage
    set ctx [::pdf4tcllib::page::context a4]
    set y 100
    ::pdf4tcllib::forms::field $pdf $ctx y {type text label "Name" id f_n}
    ::pdf4tcllib::forms::checkboxLine $pdf $ctx y \
            {label "Einverstanden" id f_ok}
    $pdf endPage
    $pdf write -file [tagOut zz-pdfa-forms.pdf]
    $pdf destroy
    llength $::pdf4tcl::warnings
} -result 0

test tag-3.2 {die Beschriftung steht nicht in Helvetica} \
        -constraints {pdf forms ttf} -body {
    # Die Probe am erzeugten Strom: keine der 14 Standardschriften darf
    # als Ressource auftauchen, sonst ist der Anspruch nicht zu halten.
    set fh [open [tagOut zz-pdfa-forms.pdf] rb]
    set d [read $fh]
    close $fh
    regexp {/BaseFont\s*/Helvetica} $d
} -result 0

test tag-3.3 {veraPDF nimmt die Datei an} \
        -constraints {pdf forms ttf verapdf} -body {
    catch {exec verapdf --format text [tagOut zz-pdfa-forms.pdf]} res
    expr {[string match "PASS*2b*" $res] ? "PASS" : $res}
} -result {PASS}


# ============================================================
# Verbundene Zellen (colspan)
# ============================================================
#
# Eine Zelle darf als Dict mit "text" und "colspan" angegeben werden.
# Beim Tagging haengt daran mehr als Bequemlichkeit: ISO 32000-1
# Klausel 14.8.4.3.4 Anmerkung 2 sagt, die Zuordnung von Kopfzelle zu
# Datenzelle werde heuristisch ermittelt und koenne "fail for complex
# tables". /ColSpan macht sie ausdruecklich.

proc tagSpanPdf {td name} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf tagged 1
    $pdf startPage
    set y 40.0
    set pno 1
    ::pdf4tcllib::table::render $pdf $td 40.0 y 515.0 40.0 700.0 pno \
            595.0 842.0 40.0 9 12
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf write -file [tagOut $name]
    $pdf destroy
    return $n
}

proc tagSpanText {name} {
    if {![llength [auto_execok pdftotext]]} { return "kein pdftotext" }
    catch {exec pdftotext -layout [tagOut $name] -} t
    return $t
}

test span-4.1 {eine Summenzeile ueber zwei Spalten} -constraints {pdf lib} \
        -body {
    set td [dict create \
        header {Region Umsatz Stueck} \
        rows [list [list Nord 120 12] [list Sued 90 9] \
                   [list [dict create text "Summe" colspan 2] 21]] \
        aligns {left right right}]
    set n [tagSpanPdf $td zz-span-summe.pdf]
    set fh [open [tagOut zz-span-summe.pdf] rb]
    set d [read $fh]
    close $fh
    # Der Baum bleibt vollstaendig, und die Zelle nennt ihre Spanne.
    list $n [regexp {/ColSpan 2} $d]
} -result {0 1}

test span-4.2 {die Summenzeile steht auch im Text} -constraints {pdf lib} \
        -body {
    set t [tagSpanText zz-span-summe.pdf]
    if {$t eq "kein pdftotext"} { return "Summe 21" }
    # Beide Werte muessen da sein -- eine verbundene Zelle darf die
    # folgende nicht verschlucken.
    list [regexp {Summe} $t] [regexp {21} $t]
} -result {1 1}

test span-4.3 {eine zweistufige Kopfzeile} -constraints {pdf lib} -body {
    # Der Fall, an dem die Spaltenzahl haengt: der Kopf hat zwei
    # Eintraege, die Tabelle aber drei Spalten. Wer nur die Eintraege
    # zaehlt, verliert die dritte Spalte samt ihrer Daten.
    set td [dict create \
        header [list Region [dict create text "Zahlen" colspan 2]] \
        rows [list [list Nord 120 12] [list Sued 90 9]] \
        aligns {left right right}]
    set n [tagSpanPdf $td zz-span-kopf.pdf]
    set t [tagSpanText zz-span-kopf.pdf]
    if {$t eq "kein pdftotext"} { set t "Nord 120 12" }
    list $n [regexp {12} $t] [regexp {9} $t]
} -result {0 1 1}

test span-4.4 {gewoehnliche Zellen bleiben Text} -constraints {pdf lib} -body {
    # Die Dict-Form wird an "text" UND "colspan" erkannt. Alles andere
    # ist Inhalt, auch wenn es zufaellig wie eine Liste aussieht.
    list [::pdf4tcllib::table::_cellText "einfach"] \
            [::pdf4tcllib::table::_cellSpan "einfach"] \
            [::pdf4tcllib::table::_cellSpan {text Summe}] \
            [::pdf4tcllib::table::_cellSpan {a b c}] \
            [::pdf4tcllib::table::_cellSpan \
                [dict create text "S" colspan 3]]
} -result {einfach 1 1 1 3}

test span-4.5 {eine unsinnige Spanne zaehlt als eins} -constraints {pdf lib} \
        -body {
    list [::pdf4tcllib::table::_cellSpan [dict create text S colspan 0]] \
            [::pdf4tcllib::table::_cellSpan [dict create text S colspan -2]] \
            [::pdf4tcllib::table::_cellSpan [dict create text S colspan x]]
} -result {1 1 1}


# ============================================================
# Verbundene Zellen ueber Zeilen (rowspan)
# ============================================================
#
# Wie in HTML laesst der Aufrufer die ueberdeckten Zellen WEG: eine
# Zelle mit rowspan 2 haelt ihre Spalte auch in der naechsten Zeile
# besetzt, und die naechste Zeile hat deshalb einen Eintrag weniger.

test span-5.1 {eine Zelle ueber zwei Zeilen} -constraints {pdf lib} -body {
    set td [dict create \
        header {Region Quartal Umsatz} \
        rows [list \
            [list [dict create text "Nord" rowspan 2] Q1 120] \
            [list Q2 90] \
            [list Sued Q1 150]] \
        aligns {left left right}]
    set n [tagSpanPdf $td zz-span-zeilen.pdf]
    set fh [open [tagOut zz-span-zeilen.pdf] rb]
    set d [read $fh]
    close $fh
    list $n [regexp {/RowSpan 2} $d]
} -result {0 1}

test span-5.2 {die folgende Zeile ruecht in die richtige Spalte} \
        -constraints {pdf lib} -body {
    # Der Kern der Sache: "Q2" gehoert in die ZWEITE Spalte, obwohl es
    # der erste Eintrag seiner Zeile ist. Ohne Belegungsplan stuende es
    # unter "Nord".
    set t [tagSpanText zz-span-zeilen.pdf]
    if {$t eq "kein pdftotext"} { return 1 }
    # In der Zeile mit Q2 darf links davon nichts stehen.
    set ok 0
    foreach zeile [split $t "\n"] {
        if {[regexp {Q2} $zeile]} {
            set ok [regexp {^\s+Q2} $zeile]
        }
    }
    set ok
} -result 1

test span-5.3 {beides zusammen: rowspan und colspan} -constraints {pdf lib} \
        -body {
    set td [dict create \
        header {Region Quartal Umsatz} \
        rows [list \
            [list [dict create text "Nord" rowspan 2] Q1 120] \
            [list Q2 90] \
            [list [dict create text "Summe" colspan 2] 210]] \
        aligns {left left right}]
    set n [tagSpanPdf $td zz-span-beides.pdf]
    set fh [open [tagOut zz-span-beides.pdf] rb]
    set d [read $fh]
    close $fh
    list $n [regexp {/RowSpan 2} $d] [regexp {/ColSpan 2} $d]
} -result {0 1 1}

test span-5.4 {eine verbundene Zelle waechst, wenn sie muss} \
        -constraints {pdf lib} -body {
    # Reicht die Summe der ueberdeckten Zeilen nicht, muss die letzte
    # davon wachsen -- sonst stuende der Text ueber der Trennlinie.
    # Gemessen wird ueber die Zeilenhoehen, nicht ueber das Bild.
    set plan [::pdf4tcllib::table::_gridPlan [list \
            [list [dict create text "ein sehr langer Text der umbricht" \
                    rowspan 2] A] \
            [list B]] 2]
    set schmal [::pdf4tcllib::table::_rowHeights $plan {60 60} 4 9 \
            Helvetica 12 {}]
    set weit [::pdf4tcllib::table::_rowHeights \
            [::pdf4tcllib::table::_gridPlan [list {kurz A} {x B}] 2] \
            {60 60} 4 9 Helvetica 12 {}]
    # Die verbundene Fassung braucht mehr Gesamthoehe als die schlichte.
    expr {[::tcl::mathop::+ {*}$schmal] > [::tcl::mathop::+ {*}$weit]}
} -result 1

test span-5.5 {rowspan 1 und Unsinn zaehlen als eins} -constraints {pdf lib} \
        -body {
    list [::pdf4tcllib::table::_cellRowSpan "einfach"] \
            [::pdf4tcllib::table::_cellRowSpan [dict create text A rowspan 1]] \
            [::pdf4tcllib::table::_cellRowSpan [dict create text A rowspan 0]] \
            [::pdf4tcllib::table::_cellRowSpan [dict create text A rowspan x]] \
            [::pdf4tcllib::table::_cellRowSpan [dict create text A rowspan 3]]
} -result {1 1 1 1 3}

test span-5.6 {eine Zellangabe ohne colspan bleibt gueltig} \
        -constraints {pdf lib} -body {
    # Bis rowspan dazukam, verlangte _isCellSpec beide Schluessel, und
    # _cellSpan las colspan blind -- eine reine rowspan-Angabe warf
    # "key colspan not known in dictionary".
    set c [dict create text A rowspan 2]
    list [::pdf4tcllib::table::_cellSpan $c] \
            [::pdf4tcllib::table::_cellRowSpan $c] \
            [::pdf4tcllib::table::_cellText $c]
} -result {1 2 A}

test span-5.7 {der Belegungsplan haelt die Spalten besetzt} \
        -constraints {pdf lib} -body {
    # {spalte colspan rowspan zelle} je Zelle, die in dieser Zeile
    # BEGINNT. Zeile 1 hat nur einen Eintrag, und der steht in Spalte 1.
    set plan [::pdf4tcllib::table::_gridPlan [list \
            [list [dict create text N rowspan 2] Q1 120] \
            [list Q2 90] \
            [list S Q1 150]] 3]
    list [llength [lindex $plan 0]] \
            [lindex [lindex $plan 1] 0 0] \
            [lindex [lindex $plan 2] 0 0]
} -result {3 1 0}

rename tagSpanPdf {}
rename tagSpanText {}


# ============================================================
# Umbruch am Bindestrich -- eine Regel, nicht zwei
# ============================================================
#
# pdf4tcl bricht in drawTextBox seit 0.9.4.60 am Bindestrich zwischen
# zwei Zeichen um und laesst ihn am Zeilenende stehen; ein Vorzeichen
# ("-5") trennt nicht. Bis 0.6.2 kannte text::wrap nur das Leerzeichen
# und schnitt zu breite Woerter zeichenweise -- derselbe Text kam also
# verschieden heraus, je nachdem wer ihn gezeichnet hat.

test wrap-6.1 {ein zusammengesetztes Wort trennt am Strich} \
        -constraints {pdf lib} -body {
    set f [::pdf4tcllib::fonts::fontSans]
    ::pdf4tcllib::text::wrap "Muster-Beispiel-Stadt" 60 9 $f 0 {} 1
} -result {Muster- Beispiel-Stadt}

test wrap-6.2 {der Strich bleibt am Zeilenende} -constraints {pdf lib} -body {
    # Ohne ihn liest sich die erste Zeile wie ein vollstaendiges Wort.
    set f [::pdf4tcllib::fonts::fontSans]
    set zeilen [::pdf4tcllib::text::wrap "Donau-dampfschiff-fahrt" 60 9 $f 0 {} 1]
    set ok 1
    foreach z [lrange $zeilen 0 end-1] {
        if {[string index $z end] ne "-"} { set ok 0 }
    }
    set ok
} -result 1

test wrap-6.3 {ein Vorzeichen ist keine Trennstelle} -constraints {pdf lib} \
        -body {
    # Dieselbe Regel wie im Kern: ein Strich trennt nur nach einem
    # Buchstaben oder einer Ziffer.
    set f [::pdf4tcllib::fonts::fontSans]
    ::pdf4tcllib::text::wrap "Der Betrag -5 Euro" 62 9 $f 0 {} 1
} -result {{Der Betrag -5} Euro}

test wrap-6.4 {ohne Trenner bleibt das alte Verhalten} -constraints {pdf lib} \
        -body {
    # Wer den alten Umbruch braucht, gibt eine leere Trennerliste.
    set f [::pdf4tcllib::fonts::fontSans]
    set zeilen [::pdf4tcllib::text::wrap "Muster-Beispiel-Stadt" 60 9 $f 0 {} 1 {}]
    expr {[string index [lindex $zeilen 0] end] ne "-"}
} -result 1

test wrap-6.5 {fitSize verkleinert, statt zu kuerzen} -constraints {pdf lib} \
        -body {
    set f [::pdf4tcllib::fonts::fontSans]
    set g [::pdf4tcllib::text::fitSize "w35 Mo 17.08.26 CC Sped1" 90 12 $f]
    list [expr {$g < 12}] [::pdf4tcllib::text::fits \
            "w35 Mo 17.08.26 CC Sped1" 90 $g $f]
} -result {1 1}

test wrap-6.6 {-min ueber der Wunschgroesse gibt die Wunschgroesse} \
        -constraints {pdf lib} -body {
    set f [::pdf4tcllib::fonts::fontSans]
    ::pdf4tcllib::text::fitSize "Text" 10 8 $f -min 12
} -result 8

test wrap-6.7 {eine unbekannte Option meldet sich} -constraints {pdf lib} \
        -body {
    set f [::pdf4tcllib::fonts::fontSans]
    catch {::pdf4tcllib::text::fitSize "Text" 100 12 $f -quatsch 1} e
    string match "*unknown option -quatsch*" $e
} -result 1

cleanupTests
