# test_forms_roundtrip.tcl -- forms::read und forms::write
#
# pdf4tclforms erzeugt Felder aus einem Schema. Die Rueckrichtung -- aus
# einem ausgefuellten PDF wieder ein Datensatz -- lieferte pdf4tcl zwar
# schon, aber in PDF-Begriffen:
#
#     f_ok -> type /Btn default /Yes value /Yes flags 0
#
# Was der Aufrufer will, ist 1. Und beim Schreiben will er 1 hinschreiben
# duerfen: die Zustandsnamen einer Checkbox stehen im /AP-Woerterbuch und
# sind eine Sache des Formats, nicht der Anwendung.

package require tcltest
namespace import ::tcltest::*

testConstraint pdf   [expr {![catch {package require pdf4tcl}]}]
testConstraint lib   [expr {![catch {package require pdf4tcllib}]}]
testConstraint forms [expr {![catch {package require pdf4tclforms}]}]

catch {::pdf4tcllib::fonts::init}

proc frOut {name} {
    set d [file join [file dirname [info script]] out]
    file mkdir $d
    return [file join $d $name]
}

set ::frSchema {
    {type text     label "Name"    id f_name}
    {type text     label "Ort"     id f_ort}
    {type checkbox label "gelesen" id f_ok}
}

# Ein leeres Formular aus dem Schema.
proc frLeer {} {
    set f [frOut zz-form-leer.pdf]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set ctx [::pdf4tcllib::page::context a4]
    set y 100
    ::pdf4tcllib::forms::field $pdf $ctx y \
            {type text label "Name" id f_name}
    ::pdf4tcllib::forms::field $pdf $ctx y \
            {type text label "Ort" id f_ort}
    ::pdf4tcllib::forms::checkboxLine $pdf $ctx y \
            {label "gelesen" id f_ok}
    $pdf endPage
    $pdf write -file $f
    $pdf destroy
    return $f
}

test fr-1.1 {ein leeres Formular liest sich als leere Werte} \
        -constraints {pdf lib forms} -body {
    ::pdf4tcllib::forms::read [frLeer]
} -result {f_name {} f_ort {} f_ok 0}

test fr-1.2 {write nimmt 1 und 0 fuer ein Ankreuzfeld} \
        -constraints {pdf lib forms} -body {
    # Ohne die Umrechnung muesste der Aufrufer /Yes und /Off kennen.
    set n [::pdf4tcllib::forms::write [frLeer] [frOut zz-form-voll.pdf] \
            {f_name "Meier" f_ok 1}]
    list $n [::pdf4tcllib::forms::read [frOut zz-form-voll.pdf]]
} -result {2 {f_name Meier f_ort {} f_ok 1}}

test fr-1.3 {der Rundlauf: lesen, aendern, schreiben, wieder lesen} \
        -constraints {pdf lib forms} -body {
    ::pdf4tcllib::forms::write [frLeer] [frOut zz-form-a.pdf] \
            {f_name "Meier" f_ok 1}
    set d [::pdf4tcllib::forms::read [frOut zz-form-a.pdf]]
    dict set d f_ok 0
    dict set d f_ort "Musterstadt"
    ::pdf4tcllib::forms::write [frOut zz-form-a.pdf] [frOut zz-form-b.pdf] $d
    ::pdf4tcllib::forms::read [frOut zz-form-b.pdf]
} -result {f_name Meier f_ort Musterstadt f_ok 0}

test fr-1.4 {-raw liefert, was getForms sagt} -constraints {pdf lib forms} \
        -body {
    set d [::pdf4tcllib::forms::read [frLeer] -raw 1]
    dict get $d f_ok type
} -result {/Btn}

test fr-1.5 {aus ist alles, was /Off heisst} -constraints {pdf lib forms} \
        -body {
    # Geprueft wird auf /Off, nicht auf /Yes: der EIN-Zustand heisst bei
    # pdf4tcl /Yes, bei einem fremden Formular kann er anders heissen.
    list [::pdf4tcllib::forms::_wertLesen {type /Btn value /Off}] \
            [::pdf4tcllib::forms::_wertLesen {type /Btn value /Yes}] \
            [::pdf4tcllib::forms::_wertLesen {type /Btn value /An}] \
            [::pdf4tcllib::forms::_wertLesen {type /Btn}]
} -result {0 1 1 0}

test fr-2.1 {mit Schema kommt die Reihenfolge des Schemas} \
        -constraints {pdf lib forms} -body {
    # Ohne Schema die des PDFs -- die muss nicht die sein, in der der
    # Aufrufer denkt.
    set ::pdf4tcl::warnings {}
    set d [::pdf4tcllib::forms::read [frLeer] -schema $::frSchema]
    list [dict keys $d] [llength $::pdf4tcl::warnings]
} -result {{f_name f_ort f_ok} 0}

test fr-2.2 {ein fehlendes Feld meldet sich} -constraints {pdf lib forms} \
        -body {
    set ::pdf4tcl::warnings {}
    ::pdf4tcllib::forms::read [frLeer] -schema {{type text id f_xy}}
    list [llength $::pdf4tcl::warnings] \
            [string match "*missing: f_xy*" [lindex $::pdf4tcl::warnings 0]]
} -result {1 1}

test fr-2.3 {-strict wirft statt zu melden} -constraints {pdf lib forms} \
        -body {
    catch {::pdf4tcllib::forms::read [frLeer] \
            -schema {{type text id f_xy}} -strict 1} e
    string match "*does not match the schema*" $e
} -result 1

test fr-2.4 {write meldet ein Feld, das es nicht gibt} \
        -constraints {pdf lib forms} -body {
    set ::pdf4tcl::warnings {}
    ::pdf4tcllib::forms::write [frLeer] [frOut zz-form-c.pdf] \
            {f_name "Meier" f_gibtsnicht "x"}
    list [llength $::pdf4tcl::warnings] \
            [string match "*no field(s): f_gibtsnicht*" \
                    [lindex $::pdf4tcl::warnings 0]]
} -result {1 1}

test fr-2.5 {und wirft mit -strict} -constraints {pdf lib forms} -body {
    catch {::pdf4tcllib::forms::write [frLeer] [frOut zz-form-d.pdf] \
            {f_gibtsnicht "x"} -strict 1} e
    string match "*no field(s)*" $e
} -result 1

test fr-3.1 {unsinnige Angaben melden sich} -constraints {pdf lib forms} \
        -body {
    catch {::pdf4tcllib::forms::read [frLeer] -quatsch 1} e1
    catch {::pdf4tcllib::forms::read /gibt/es/nicht.pdf} e2
    catch {::pdf4tcllib::forms::write [frLeer] [frOut zz-x.pdf] {}} e3
    list [string match "*unknown option -quatsch*" $e1] \
            [string match "*cannot read*" $e2] \
            [string match "*nothing to fill in*" $e3]
} -result {1 1 1}

rename frLeer {}
rename frOut {}

cleanupTests
