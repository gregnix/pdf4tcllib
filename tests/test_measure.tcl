# test_measure.tcl -- messen, ohne zu zeichnen
#
# Ein Layouter muss fragen koennen, wie hoch ein Block wird, bevor er
# weiss, auf welche Seite er kommt. Kein Baustein beantwortet das; alle
# zeichnen und geben hinterher ein y zurueck.
#
# Der billige Weg waere ein -dryrun in jeder Zeichenprozedur. Das hiesse,
# in jeder von ihnen zwei Faelle zu fuehren, und der Messfall wuerde
# seltener benutzt als der Zeichenfall -- also wuerde er als erster
# falsch. Hier wird stattdessen wirklich gezeichnet, nur in ein
# Wegwerf-Dokument. Was gemessen wird, ist damit per Bauart dasselbe, was
# spaeter herauskommt.

package require tcltest
namespace import ::tcltest::*

testConstraint pdf [expr {![catch {package require pdf4tcl}]}]
testConstraint lib [expr {![catch {package require pdf4tcllib}]}]

catch {::pdf4tcllib::fonts::init}

set ::meCols {{-header A -align left} {-header B -align right}}

proc meRows {n} {
    set r {}
    for {set i 0} {$i < $n} {incr i} { lappend r [list "Zeile $i" $i] }
    return $r
}

test me-1.1 {die Hoehe eines Blocks, ohne ihn zu zeichnen} \
        -constraints {pdf lib} -body {
    set rows [meRows 5]
    set h [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::table::draw $mp 0 0 $::meCols $rows -maxwidth 300
    }]
    expr {$h > 0}
} -result 1

test me-1.2 {gemessen ist, was spaeter gezeichnet wird} \
        -constraints {pdf lib} -body {
    # Der Kern der Sache: die Messung entsteht durch dasselbe Zeichnen,
    # also darf sie nicht abweichen.
    set rows [meRows 5]
    set h [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::table::draw $mp 0 0 $::meCols $rows -maxwidth 300
    }]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1]
    $pdf startPage
    set yend [::pdf4tcllib::table::draw $pdf 0 0 $::meCols $rows -maxwidth 300]
    $pdf destroy
    expr {abs($h - $yend) < 0.001}
} -result 1

test me-1.3 {mehr Zeilen brauchen mehr Hoehe} -constraints {pdf lib} -body {
    set klein [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::table::draw $mp 0 0 $::meCols [meRows 3] -maxwidth 300
    }]
    set gross [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::table::draw $mp 0 0 $::meCols [meRows 30] -maxwidth 300
    }]
    expr {$gross > $klein}
} -result 1

test me-1.4 {die Seitenzahl kommt mit} -constraints {pdf lib} -body {
    # Nur wenn der Block seine Grenzen kennt: ohne -ctx bricht
    # table::draw nicht um und zeichnet ueber den Seitenrand hinaus.
    # Deshalb muss gemessen werden, WIE spaeter gezeichnet wird.
    set ctx [::pdf4tcllib::page::context a4]
    set rows [meRows 80]
    set m [::pdf4tcllib::measure::block mp {
        ::pdf4tcllib::table::draw $mp [dict get $ctx SX] [dict get $ctx SY] \
                $::meCols $rows -maxwidth 480 -ctx $ctx
    } -paper a4 -y [dict get $ctx SY]]
    list [expr {[dict get $m pages] > 1}] [expr {[dict get $m height] > 0}]
} -result {1 1}

test me-1.5 {ohne Grenzen bleibt es eine Seite} -constraints {pdf lib} -body {
    # Die Gegenprobe dazu -- damit niemand die Seitenzahl fuer eine
    # Eigenschaft des Blocks haelt.
    set m [::pdf4tcllib::measure::block mp {
        ::pdf4tcllib::table::draw $mp 0 0 $::meCols [meRows 80] -maxwidth 300
    }]
    dict get $m pages
} -result 1

test me-1.6 {fits prueft Hoehe und Seitenzahl} -constraints {pdf lib} -body {
    set klein [::pdf4tcllib::measure::fits 200 mp {
        ::pdf4tcllib::table::draw $mp 0 0 $::meCols [meRows 2] -maxwidth 300
    }]
    set gross [::pdf4tcllib::measure::fits 50 mp {
        ::pdf4tcllib::table::draw $mp 0 0 $::meCols [meRows 20] -maxwidth 300
    }]
    list $klein $gross
} -result {1 0}

test me-1.7 {der Rueckgabewert des Blocks kommt durch} \
        -constraints {pdf lib} -body {
    set m [::pdf4tcllib::measure::block mp { expr {6 * 7} }]
    # height ist der Abstand zum Startwert -y, hier also 42.
    list [dict get $m value] [expr {[dict get $m height] == 42}]
} -result {42 1}

test me-1.8 {ein Block ohne Zahl gibt keine Hoehe vor} \
        -constraints {pdf lib} -body {
    # Geraten wird nicht: wer nichts Messbares zurueckgibt, bekommt den
    # leeren String und keine erfundene Zahl.
    # "return" im Block wuerde die aufrufende Prozedur verlassen, nicht
    # nur den Block -- deshalb der Wert als letzter Ausdruck.
    set m [::pdf4tcllib::measure::block mp { set x "nichts Messbares" }]
    list [dict get $m height] [dict get $m value]
} -result {{} {nichts Messbares}}

test me-1.9 {eine belegte Variable stoert nicht} -constraints {pdf lib} \
        -body {
    # upvar auf einen Namen, den der Aufrufer schon benutzt, gab
    # "variable already exists".
    set mp "etwas anderes"
    set h [::pdf4tcllib::measure::height mp {
        ::pdf4tcllib::table::draw $mp 0 0 $::meCols [meRows 1] -maxwidth 300
    }]
    expr {$h > 0}
} -result 1

test me-1.10 {ein Fehler im Block kommt durch} -constraints {pdf lib} -body {
    # Und das Wegwerf-Dokument wird trotzdem aufgeraeumt.
    set vorher [llength [info commands ::oo::Obj*]]
    catch {::pdf4tcllib::measure::block mp { error "mittendrin" }} e
    set nachher [llength [info commands ::oo::Obj*]]
    list $e [expr {$nachher <= $vorher}]
} -result {mittendrin 1}

test me-1.11 {unbekannte Option meldet sich} -constraints {pdf lib} -body {
    catch {::pdf4tcllib::measure::block mp { expr 1 } -quatsch 1} e
    string match "*unknown option -quatsch*" $e
} -result 1

rename meRows {}

cleanupTests
