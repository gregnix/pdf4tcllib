# test_layout_stack.tcl -- Bloecke untereinander setzen
#
# Was ein Aufrufer heute von Hand schreibt: einen Block zeichnen, das
# zurueckgegebene y nehmen, einen Abstand addieren, den naechsten
# zeichnen -- und beim Seitenumbruch selbst aufpassen. Die Schleife
# steckt in jedem Bericht und ist jedes Mal ein wenig anders falsch.
#
# stack benutzt dabei, was vorher entstand: measure, um VORHER zu wissen,
# ob ein Block noch auf die Seite passt, und state, damit ein Block dem
# naechsten nicht die Schrift verstellt.

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

set ::stCols {{-header A -align left}}

proc stRows {n} {
    set r {}
    for {set i 0} {$i < $n} {incr i} { lappend r [list "Zeile $i"] }
    return $r
}

test st-1.1 {Bloecke stehen untereinander} -constraints {pdf lib} -body {
    set f [::pdf4tcllib::fonts::fontSans]
    set rows [stRows 2]
    set cols $::stCols
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set r [::pdf4tcllib::layout::stack $pdf 40 60 400 [list \
        [dict create script {::pdf4tcllib::text::writeParagraph $bpdf \
                "Ein Absatz." $bx $by $bw}] \
        [dict create script {::pdf4tcllib::table::draw $bpdf $bx $by \
                $cols $rows -maxwidth $bw}] \
    ] -font [list 10 $f]]
    $pdf destroy
    set boxen [dict get $r boxes]
    # Der zweite faengt dort an, wo der erste aufhoert.
    lassign [lindex $boxen 0] x1 y1 w1 h1
    lassign [lindex $boxen 1] x2 y2 w2 h2
    list [llength $boxen] [expr {abs($y2 - ($y1 + $h1)) < 0.01}]
} -result {2 1}

test st-1.2 {jeder Block liefert dieselbe Form} -constraints {pdf lib} -body {
    # Der Sinn der Sache: table::draw gibt ein y zurueck, image::place
    # eine Flaeche, callout eine Zeilenzahl. Hier kommt von allen
    # {x y w h}.
    set f [::pdf4tcllib::fonts::fontSans]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set r [::pdf4tcllib::layout::stack $pdf 40 60 400 [list \
        [dict create script {::pdf4tcllib::text::writeParagraph $bpdf \
                "Ein Absatz." $bx $by $bw}] \
    ] -font [list 10 $f]]
    $pdf destroy
    set b [lindex [dict get $r boxes] 0]
    list [llength $b] [expr {[lindex $b 3] > 0}]
} -result {4 1}

test st-1.3 {gap schiebt weiter} -constraints {pdf lib} -body {
    set f [::pdf4tcllib::fonts::fontSans]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set mitGap [::pdf4tcllib::layout::stack $pdf 40 60 400 [list \
        [dict create script {::pdf4tcllib::text::writeParagraph $bpdf \
                "A." $bx $by $bw}] \
        {gap 50} \
        [dict create script {::pdf4tcllib::text::writeParagraph $bpdf \
                "B." $bx $by $bw}] \
    ] -font [list 10 $f]]
    $pdf destroy
    lassign [lindex [dict get $mitGap boxes] 0] x1 y1 w1 h1
    lassign [lindex [dict get $mitGap boxes] 1] x2 y2 w2 h2
    expr {abs($y2 - ($y1 + $h1 + 50)) < 0.01}
} -result 1

test st-1.4 {keep bricht vorher um, statt aufzuteilen} \
        -constraints {pdf lib} -body {
    # Der Block wird gemessen, bevor er gezeichnet wird: passt er nicht
    # mehr ganz, faengt er auf der naechsten Seite an.
    set f [::pdf4tcllib::fonts::fontSans]
    set ctx [::pdf4tcllib::page::context a4]
    set cols $::stCols
    set rows [stRows 25]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set r [::pdf4tcllib::layout::stack $pdf [dict get $ctx SX] \
            [dict get $ctx SY] 400 [list \
        [dict create script {::pdf4tcllib::table::draw $bpdf $bx $by \
                $cols $rows -maxwidth $bw}] \
        [dict create script {::pdf4tcllib::table::draw $bpdf $bx $by \
                $cols $rows -maxwidth $bw} keep 1] \
    ] -ctx $ctx -font [list 9 $f]]
    set seiten [$pdf pageCount]
    $pdf destroy
    # Ein Seitenwechsel, und der zweite Block faengt oben an.
    lassign [lindex [dict get $r boxes] 1] x2 y2
    list [dict get $r pages] $seiten \
            [expr {abs($y2 - [dict get $ctx SY]) < 0.01}]
} -result {1 2 1}

test st-1.5 {ohne keep wird nicht umgebrochen} -constraints {pdf lib} -body {
    # Ohne die Angabe wird nicht gemessen und nicht umgebrochen -- der
    # Block regelt es selbst, wie bisher.
    set f [::pdf4tcllib::fonts::fontSans]
    set ctx [::pdf4tcllib::page::context a4]
    set cols $::stCols
    set rows [stRows 25]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set r [::pdf4tcllib::layout::stack $pdf [dict get $ctx SX] \
            [dict get $ctx SY] 400 [list \
        [dict create script {::pdf4tcllib::table::draw $bpdf $bx $by \
                $cols $rows -maxwidth $bw}] \
        [dict create script {::pdf4tcllib::table::draw $bpdf $bx $by \
                $cols $rows -maxwidth $bw}] \
    ] -ctx $ctx -font [list 9 $f]]
    $pdf destroy
    dict get $r pages
} -result 0

test st-1.6 {ein Block verstellt dem naechsten nicht die Schrift} \
        -constraints {pdf lib} -body {
    # -font wird vor jedem Block gesetzt und danach wiederhergestellt.
    set f [::pdf4tcllib::fonts::fontSans]
    set cols $::stCols
    set rows [stRows 1]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    ::pdf4tcllib::layout::stack $pdf 40 60 400 [list \
        [dict create script {::pdf4tcllib::table::draw $bpdf $bx $by \
                $cols $rows -maxwidth $bw}] \
        [dict create script {$bpdf text "danach" -x $bx -y $by ; expr {$by + 14}}] \
    ] -font [list 14 $f]
    set out [$pdf get]
    $pdf destroy
    # Der zweite Block zeichnet roh, uebernimmt also die eingestellte
    # Schrift: 14 Punkt, nicht die 9 der Tabelle davor.
    # (writeParagraph waere kein Beleg -- das setzt seine eigene Groesse.)
    set tf ""
    foreach l [split $out "\n"] {
        if {[regexp {^/\S+ ([0-9.]+) Tf$} $l -> g]} { set tf $g }
        if {[string match "*(danach)*" $l]} { break }
    }
    expr {$tf == 14}
} -result 1

test st-1.7 {die Variablen des Aufrufers sind sichtbar} \
        -constraints {pdf lib} -body {
    # Das Skript wird im Gueltigkeitsbereich des Aufrufers ausgewertet --
    # sonst muesste jede Zeile, jede Spalte durchgereicht werden.
    set f [::pdf4tcllib::fonts::fontSans]
    set meinText "aus dem Aufrufer"
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    ::pdf4tcllib::layout::stack $pdf 40 60 400 [list \
        [dict create script {::pdf4tcllib::text::writeParagraph $bpdf \
                $meinText $bx $by $bw}] \
    ] -font [list 10 $f]
    set out [$pdf get]
    $pdf destroy
    regexp {aus dem Aufrufer} $out
} -result 1

test st-1.8 {stack hinterlaesst keine Variablen} -constraints {pdf lib} \
        -body {
    # bpdf, bx, by, bw werden gesetzt und danach wieder entfernt.
    set f [::pdf4tcllib::fonts::fontSans]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    ::pdf4tcllib::layout::stack $pdf 40 60 400 [list \
        [dict create script {::pdf4tcllib::text::writeParagraph $bpdf \
                "x" $bx $by $bw}] \
    ] -font [list 10 $f]
    $pdf destroy
    list [info exists bpdf] [info exists bx] [info exists by] [info exists bw]
} -result {0 0 0 0}

test st-1.9 {ein Eintrag ohne script meldet sich} -constraints {pdf lib} \
        -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::layout::stack $pdf 40 60 400 {{quatsch 1}}} e1
    catch {::pdf4tcllib::layout::stack $pdf 40 60 400 {} -quatsch 1} e2
    $pdf destroy
    list [string match "*needs a script*" $e1] \
            [string match "*unknown option -quatsch*" $e2]
} -result {1 1}

rename stRows {}

cleanupTests
