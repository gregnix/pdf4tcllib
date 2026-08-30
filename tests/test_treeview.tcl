# test_treeview.tcl -- Tests fuer pdf4tcltreeview
#
# Ein ttk::treeview ist zweierlei zugleich: eine Tabelle mit Spalten und
# ein Baum. Beide Lesarten werden hier geprueft -- render zeichnet die
# Tabelle, outline die Gliederung -- und beide muessen einen
# vollstaendigen Strukturbaum hinterlassen, sonst ist der Export fuer ein
# Vorleseprogramm wertlos.
#
# Das Modul ist ein Adapter: es liest das Widget und reicht an
# ::pdf4tcllib::table::draw weiter. Geprueft wird deshalb vor allem, ob
# es RICHTIG liest -- Spalten, Ausrichtung, Tiefe, geschlossene Aeste.

package require tcltest
namespace import ::tcltest::*

# Damit die Datei auch EINZELN laeuft. Ohne diese Zeile findet sie
# pdf4tcllib nur ueber ein installiertes Paket -- und die Constraints
# unten fragen genau danach. Fehlt es, ueberspringt tcltest still
# ALLES und meldet trotzdem Erfolg: Rueckgabewert 0, Failed 0. Der
# Runner setzt den Pfad selbst, deshalb fiel es nie auf.
tcl::tm::path add [file join [file dirname [file normalize [info script]]] .. lib]

testConstraint pdf [expr {![catch {package require pdf4tcl}]}]
testConstraint tk  [expr {![catch {package require Tk}] && ![catch {
    ttk::treeview .tvProbe ; destroy .tvProbe}]}]
testConstraint tv  [expr {![catch {package require pdf4tcltreeview}]}]
testConstraint pdftotext [expr {[llength [auto_execok pdftotext]] > 0}]

catch {::pdf4tcllib::fonts::init}

proc tvOut {name} {
    set d [file join [file dirname [info script]] out]
    file mkdir $d
    return [file join $d $name]
}

# Ein Widget mit zwei Ebenen und zwei Wertespalten.
proc tvNew {{offen 1}} {
    catch {destroy .tvT}
    ttk::treeview .tvT -columns {menge preis} -show {tree headings}
    .tvT heading #0 -text "Artikel"
    .tvT heading menge -text "Menge"
    .tvT heading preis -text "Preis"
    .tvT column menge -anchor e
    .tvT column preis -anchor e
    set a [.tvT insert {} end -text "Schrauben" -values {100 4.90} -open $offen]
    .tvT insert $a end -text "M6" -values {60 2.90}
    .tvT insert $a end -text "M8" -values {40 2.00}
    .tvT insert {} end -text "Muttern" -values {200 3.50}
    pack .tvT
    update idletasks
    return .tvT
}

# Die x-Werte der Textmarken aus dem Strom -- damit laesst sich die
# Einrueckung messen, ohne das Bild anzusehen.
proc tvXs {out} {
    set xs {}
    foreach l [split $out "\n"] {
        if {[regexp {^1 0 0 1 ([0-9.]+) [0-9.]+ Tm} $l -> x]} { lappend xs $x }
    }
    return $xs
}

# ============================================================
# render -- die Tabellenlesart
# ============================================================

test tv-1.1 {der Baum wird als Tabelle gezeichnet} \
        -constraints {pdf tk tv} -body {
    set tv [tvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    set yend [::pdf4tcllib::treeview::render $pdf $tv 40 60 -maxwidth 400]
    set out [$pdf get]
    $pdf destroy
    destroy .tvT
    # Vier Knoten plus Kopfzeile, und y ist weitergerueckt.
    list [expr {$yend > 60}] [regexp {Schrauben} $out] [regexp {Muttern} $out]
} -result {1 1 1}

test tv-1.2 {der Strukturbaum bleibt vollstaendig} \
        -constraints {pdf tk tv} -body {
    set tv [tvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::treeview::render $pdf $tv 40 60 -maxwidth 400
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf write -file [tvOut zz-treeview.pdf]
    $pdf destroy
    destroy .tvT
    set n
} -result 0

test tv-1.3 {Kinder werden eingerueckt, ohne -tree nicht} \
        -constraints {pdf tk tv} -body {
    # Die Probe ohne Bild: die x-Werte der ersten Spalte. Mit Baum steht
    # ein Kind weiter rechts als sein Elternteil, ohne Baum nicht.
    set tv [tvNew]
    set res {}
    foreach tree {1 0} {
        set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
        $pdf startPage
        ::pdf4tcllib::treeview::render $pdf $tv 40 60 -maxwidth 400 -tree $tree
        set xs [tvXs [$pdf get]]
        $pdf destroy
        # Jede zweite Marke gehoert zur ersten Spalte (drei Spalten, aber
        # nur die erste interessiert): der kleinste und der groesste Wert
        # der linken Spalte.
        set links {}
        foreach x $xs { if {$x < 100} { lappend links $x } }
        lappend res [expr {[llength [lsort -unique $links]] > 1}]
    }
    destroy .tvT
    set res
} -result {1 0}

test tv-1.4 {ein geschlossener Ast bleibt zu} -constraints {pdf tk tv} -body {
    # Das PDF soll zeigen, was zu sehen war. Wer alles will, nimmt -all 1.
    set tv [tvNew 0]
    set res {}
    foreach alle {0 1} {
        set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
        $pdf startPage
        ::pdf4tcllib::treeview::render $pdf $tv 40 60 -maxwidth 400 -all $alle
        lappend res [regexp {M8} [$pdf get]]
        $pdf destroy
    }
    destroy .tvT
    set res
} -result {0 1}

test tv-1.5 {die Ausrichtung kommt aus dem Widget} \
        -constraints {pdf tk tv} -body {
    # -anchor e am Widget muss rechtsbuendig im PDF werden, sonst stehen
    # Zahlen linksbuendig unter ihrer Ueberschrift.
    set tv [tvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    ::pdf4tcllib::treeview::render $pdf $tv 40 60 -maxwidth 400
    set xs [tvXs [$pdf get]]
    $pdf destroy
    destroy .tvT
    # Die Zahlenspalten stehen rechts; ihre x-Werte sind nicht alle gleich,
    # weil "100" und "60" verschieden breit sind.
    set rechts {}
    foreach x $xs { if {$x > 100} { lappend rechts $x } }
    expr {[llength [lsort -unique $rechts]] > 1}
} -result 1

test tv-1.6 {eine unbekannte Option meldet sich} -constraints {pdf tk tv} \
        -body {
    set tv [tvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf startPage
    catch {::pdf4tcllib::treeview::render $pdf $tv 40 60 -quatsch 1} e
    $pdf destroy
    destroy .tvT
    string match "*unknown option -quatsch*" $e
} -result 1

test tv-1.7 {ein Widget, das es nicht gibt} -constraints {pdf tk tv} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf startPage
    catch {::pdf4tcllib::treeview::render $pdf .gibtsNicht 40 60} e
    $pdf destroy
    string match "*no such widget*" $e
} -result 1

# ============================================================
# outline -- die Baumlesart
# ============================================================

test tv-2.1 {die Gliederung traegt L, LI und LBody} \
        -constraints {pdf tk tv} -body {
    # Beim Tabellen-Export ist Table/TR/TD richtig, hier nicht: eine
    # Gliederung ist eine Liste, und ein Vorleseprogramm kuendigt sie
    # anders an.
    set tv [tvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::treeview::outline $pdf $tv 40 60 -all 1
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf write -file [tvOut zz-treeview-outline.pdf]
    $pdf destroy
    destroy .tvT
    set fh [open [tvOut zz-treeview-outline.pdf] rb]
    set d [read $fh]
    close $fh
    # \b ist in Tcl das Rueckschrittzeichen, nicht die Wortgrenze -- die
    # heisst \y. Ein Fund, der eine Viertelstunde gekostet hat.
    list $n [regexp {/S /L\y} $d] [regexp {/S /LI} $d] [regexp {/S /LBody} $d]
} -result {0 1 1 1}

test tv-2.2 {die Tiefe wird eingerueckt} -constraints {pdf tk tv} -body {
    set tv [tvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    ::pdf4tcllib::treeview::outline $pdf $tv 40 60 -all 1 -indentW 20
    set xs [tvXs [$pdf get]]
    $pdf destroy
    destroy .tvT
    # Zwei Ebenen, also zwei verschiedene x-Werte, und der zweite liegt
    # genau eine Einrueckung weiter rechts.
    set u [lsort -real -unique $xs]
    list [llength $u] [expr {[lindex $u 1] - [lindex $u 0] == 20}]
} -result {2 1}

test tv-2.3 {y wandert je Zeile weiter} -constraints {pdf tk tv} -body {
    set tv [tvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf startPage
    set yend [::pdf4tcllib::treeview::outline $pdf $tv 40 60 -all 1 \
            -fontsize 10 -lineH 15]
    $pdf destroy
    destroy .tvT
    # Vier Knoten mal 15 Punkt.
    expr {$yend - 60 == 60}
} -result 1

cleanupTests
