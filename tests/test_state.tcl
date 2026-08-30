# test_state.tcl -- Zeichenzustand um einen Baustein herum erhalten
#
# Ein Baustein hinterlaesst Schrift und Farbe so, wie er sie zuletzt
# brauchte, nicht so, wie er sie vorfand. Gemessen an table::draw:
#
#     vorher   /Pdf4tclSansBold 20 Tf,  1 0 0 rg
#     nachher  /Pdf4tclSans 9 Tf,       0 0 0 rg
#
# Wer von Hand zeichnet, merkt es kaum. Wer Bausteine hintereinander
# setzt -- ein Layouter tut nichts anderes -- bekommt Ergebnisse, die von
# der Reihenfolge abhaengen.
#
# WARUM NICHT gsave/grestore: das PDF-Paar q/Q gilt je Inhaltsstrom, und
# jede Seite hat ihren eigenen. Ein q auf Seite 1 und das Q auf Seite 2
# ergibt zwei unausgeglichene Stroeme -- und genau das passiert bei jedem
# Baustein, der selbst umbrechen kann.

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

# Der letzte Tf- und rg-Befehl vor einer Textmarke.
proc stZustand {out marke} {
    set tf "" ; set rg ""
    foreach l [split $out "\n"] {
        if {[regexp {^(/\S+ [0-9.]+) Tf$} $l -> v]} { set tf $v }
        if {[regexp {^([0-9. ]+) rg$} $l -> v]} { set rg [string trim $v] }
        if {[string match "*($marke)*" $l]} { return [list $tf $rg] }
    }
    return [list "" ""]
}

test state-1.1 {ein Baustein aendert Schrift und Farbe} \
        -constraints {pdf lib} -body {
    # Der Befund, um den es geht -- ohne ihn waere alles Weitere
    # Behauptung.
    set f [::pdf4tcllib::fonts::fontSansBold]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    $pdf setFont 20 $f
    $pdf setFillColor 1 0 0
    $pdf text "VORHER" -x 40 -y 20
    ::pdf4tcllib::table::draw $pdf 40 40 {{-header A -align left}} \
            {{x}} -maxwidth 200
    $pdf text "NACHHER" -x 40 -y 300
    set out [$pdf get]
    $pdf destroy
    expr {[stZustand $out VORHER] ne [stZustand $out NACHHER]}
} -result 1

test state-1.2 {mit state::with bleibt er erhalten} -constraints {pdf lib} \
        -body {
    set f [::pdf4tcllib::fonts::fontSansBold]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    $pdf setFont 20 $f
    $pdf setFillColor 1 0 0
    $pdf text "VORHER" -x 40 -y 20
    ::pdf4tcllib::state::with $pdf [list 20 $f] {1 0 0} {
        ::pdf4tcllib::table::draw $pdf 40 40 {{-header A -align left}} \
                {{x}} -maxwidth 200
    }
    $pdf text "NACHHER" -x 40 -y 300
    set out [$pdf get]
    $pdf destroy
    expr {[stZustand $out VORHER] eq [stZustand $out NACHHER]}
} -result 1

test state-1.3 {save und restore einzeln} -constraints {pdf lib} -body {
    set f [::pdf4tcllib::fonts::fontSansBold]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    $pdf setFont 20 $f
    $pdf setFillColor 1 0 0
    $pdf text "VORHER" -x 40 -y 20
    set z [::pdf4tcllib::state::save $pdf 20 $f {1 0 0}]
    ::pdf4tcllib::table::draw $pdf 40 40 {{-header A -align left}} \
            {{x}} -maxwidth 200
    ::pdf4tcllib::state::restore $pdf $z
    $pdf text "NACHHER" -x 40 -y 300
    set out [$pdf get]
    $pdf destroy
    expr {[stZustand $out VORHER] eq [stZustand $out NACHHER]}
} -result 1

test state-1.4 {auch wenn der Block wirft} -constraints {pdf lib} -body {
    # Sonst haette ein Fehler mitten im Dokument den Zustand verstellt,
    # und was danach kommt, saehe anders aus als gedacht.
    set f [::pdf4tcllib::fonts::fontSansBold]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    $pdf setFont 20 $f
    $pdf setFillColor 1 0 0
    $pdf text "VORHER" -x 40 -y 20
    set rc [catch {
        ::pdf4tcllib::state::with $pdf [list 20 $f] {1 0 0} {
            $pdf setFont 8 [::pdf4tcllib::fonts::fontSans]
            $pdf setFillColor 0 0 1
            error "mittendrin"
        }
    } e]
    $pdf text "NACHHER" -x 40 -y 300
    set out [$pdf get]
    $pdf destroy
    list $rc $e [expr {[stZustand $out VORHER] eq [stZustand $out NACHHER]}]
} -result {1 mittendrin 1}

test state-1.5 {der Rueckgabewert des Blocks kommt durch} \
        -constraints {pdf lib} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf startPage
    set r [::pdf4tcllib::state::with $pdf {12 Helvetica} {0 0 0} {
        expr {6 * 7}
    }]
    $pdf destroy
    set r
} -result 42

test state-1.6 {was nicht gesichert wurde, wird nicht angefasst} \
        -constraints {pdf lib} -body {
    # Eine Voreinstellung waere hier eine Behauptung: wer keine Farbe
    # angibt, will seine behalten, nicht Schwarz.
    set z [::pdf4tcllib::state::save $pdf 12 Helvetica]
    list [dict exists $z size] [dict exists $z fill] [dict exists $z stroke]
} -setup {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
} -cleanup {
    $pdf destroy
} -result {1 0 0}

test state-2.1 {q/Q ueberlebt keinen Seitenwechsel} -constraints {pdf lib} \
        -body {
    # Der Grund, warum state:: nicht einfach gsave/grestore ruft: das q
    # steht im Strom der einen Seite, das Q im Strom der naechsten.
    # Beide Stroeme bleiben fuer sich lesbar -- deshalb meldet weder
    # pdf4tcl noch qpdf etwas, und der Fehler faellt erst im Leser auf.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    $pdf setFont 12 [::pdf4tcllib::fonts::fontSans]
    $pdf gsave
    $pdf text "eins" -x 40 -y 40
    $pdf endPage
    $pdf startPage
    $pdf setFont 12 [::pdf4tcllib::fonts::fontSans]
    $pdf text "zwei" -x 40 -y 40
    $pdf grestore
    $pdf endPage
    set out [$pdf get]
    $pdf destroy
    # q und Q liegen in verschiedenen Stroemen.
    set strom 0 ; set qStrom -1 ; set QStrom -1
    foreach l [split $out "\n"] {
        if {[string match "*stream*" $l]} { incr strom }
        if {$l eq "q"} { set qStrom $strom }
        if {$l eq "Q"} { set QStrom $strom }
    }
    expr {$qStrom != $QStrom}
} -result 1


# ============================================================
# Die Richtung -- wer sie kennt und wer nicht
# ============================================================
#
# Das Dokument weiss, in welche Richtung y laeuft. Ein Baustein sollte
# das nicht noch einmal gesagt bekommen; text::writeParagraph fragt seit
# jeher das Objekt, table::draw verlangte eine Option mit der Vorgabe 1.

test or-3.1 {draw lehnt -orient 0 ab, statt falsch zu zeichnen} \
        -constraints {pdf lib} -body {
    # Die Richtung kommt jetzt aus dem Dokument. Sie zu befolgen kann
    # draw aber nur beim Seitenumbruch, nicht bei den Zeilen -- unter
    # -orient 0 waechst die Tabelle nach oben und die Kopfzeile steht
    # unten. Eine Bibliothek, die weiss, dass sie falsch zeichnet, sollte
    # es nicht trotzdem tun.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 0]
    $pdf startPage
    set rc [catch {::pdf4tcllib::table::draw $pdf 40 100 {{-header K}} \
            {{a}} -maxwidth 200} e]
    $pdf destroy
    list $rc [string match "*-orient 0 is not supported*" $e]
} -result {1 1}

test or-3.2 {die Meldung nennt den Ausweg} -constraints {pdf lib} -body {
    # Ein Fehler, der nur "geht nicht" sagt, kostet den naechsten eine
    # halbe Stunde.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 0]
    $pdf startPage
    catch {::pdf4tcllib::table::draw $pdf 40 100 {{-header K}} {{a}} \
            -maxwidth 200} e
    $pdf destroy
    list [string match "*page::context measures top and bottom*" $e] \
            [string match "*-orient 1*" $e]
} -result {1 1}

test or-3.3 {bei -orient 1 zeichnet es} -constraints {pdf lib} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1]
    $pdf startPage
    set rc [catch {::pdf4tcllib::table::draw $pdf 40 100 {{-header K}} \
            {{a}} -maxwidth 200}]
    $pdf destroy
    set rc
} -result 0

test or-3.3b {und eine ausdrueckliche Angabe gewinnt} -constraints {pdf lib} \
        -body {
    # Wer -orient 1 auf einem -orient-0-Dokument angibt, weiss, was er
    # tut, und bekommt seine Tabelle.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 0]
    $pdf startPage
    set rc [catch {::pdf4tcllib::table::draw $pdf 40 100 {{-header K}} \
            {{a}} -maxwidth 200 -orient 1}]
    $pdf destroy
    set rc
} -result 0

test or-3.4 {writeParagraph rechnet in beide Richtungen} \
        -constraints {pdf lib} -body {
    # Der Baustein, der es richtig macht -- und der Massstab fuer die
    # anderen: unter orient 1 waechst y nach unten, unter orient 0 nach
    # oben, und der Rueckgabewert folgt dem.
    set res {}
    foreach or {1 0} {
        set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient $or]
        $pdf startPage
        $pdf setFont 10 [::pdf4tcllib::fonts::fontSans]
        set y [::pdf4tcllib::text::writeParagraph $pdf "Ein Absatz." 40 100 300]
        $pdf destroy
        lappend res [expr {$y > 100}]
    }
    set res
} -result {1 0}

rename stZustand {}

cleanupTests
