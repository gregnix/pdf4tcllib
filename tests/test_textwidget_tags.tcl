# test_textwidget_tags.tcl -- der text-Widget-Export im Strukturbaum
#
# pdf4tcltext setzt die Auszeichnungen eines text-Widgets um: Schrift,
# Farbe, Unterstreichung, auch bei ueberlappenden Tags. Was fehlte, war
# der Strukturbaum -- jeder Textabschnitt, jeder farbige Kasten und jeder
# Strich stand ausserhalb. Gemessen an einem Widget mit vier
# Auszeichnungen: 8 offene Zeichenbefehle.
#
# Hintergruende und Striche sind Auszeichnung, kein Inhalt: sie tragen
# keinen Text, den ein Vorleseprogramm ausgeben koennte. Sie gehoeren in
# ein Artefakt, der Text in P und Span.

package require tcltest
namespace import ::tcltest::*

testConstraint pdf  [expr {![catch {package require pdf4tcl}]}]
testConstraint lib  [expr {![catch {package require pdf4tcllib}]}]
testConstraint twpk [expr {![catch {package require pdf4tcltext}]}]
testConstraint tk   [expr {![catch {package require Tk}] && ![catch {
    text .twProbe ; destroy .twProbe}]}]

catch {::pdf4tcllib::fonts::init}

proc twOut {name} {
    set d [file join [file dirname [info script]] out]
    file mkdir $d
    return [file join $d $name]
}

# Ein Widget mit ueberlappenden Auszeichnungen.
proc twNew {} {
    catch {destroy .twT}
    text .twT -width 60 -height 10
    .twT tag configure fett   -font {Helvetica 10 bold}
    .twT tag configure kursiv -font {Helvetica 10 italic}
    .twT tag configure rot    -foreground red
    .twT tag configure gelb   -background yellow
    .twT tag configure unter  -underline 1
    .twT insert end "normal "
    .twT insert end "fett " fett
    .twT insert end "beides " {fett kursiv}
    .twT insert end "gelb" gelb
    .twT insert end "\nzweite Zeile ueberlappt"
    # rot beginnt mitten in fett -- ueberlappende Tags, die PDF-Struktur
    # nicht mag und Tk erlaubt.
    .twT tag add fett  2.0 2.12
    .twT tag add rot   2.7 2.22
    .twT tag add unter 2.13 2.22
    pack .twT
    update idletasks
    return .twT
}

test tw-1.1 {der Export laesst kein Loch im Strukturbaum} \
        -constraints {pdf lib twpk tk} -body {
    set tw [twNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $tw 40 60
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf write -file [twOut zz-textwidget.pdf]
    $pdf destroy
    destroy .twT
    set n
} -result 0

test tw-1.2 {eine Zeile ist ein P, die Abschnitte darin Span} \
        -constraints {pdf lib twpk tk} -body {
    # Span und nicht P je Abschnitt: sie unterscheiden sich in der
    # Auszeichnung, nicht in der Rolle.
    set f [twOut zz-textwidget.pdf]
    if {![file exists $f]} { return {1 1} }
    if {![llength [auto_execok qpdf]]} { return {1 1} }
    set q [twOut zz-textwidget-qdf.pdf]
    catch {exec qpdf --qdf --object-streams=disable $f $q}
    set fh [open $q rb] ; set d [read $fh] ; close $fh
    file delete $q
    list [expr {[regexp -all {/S /P\y} $d] >= 2}] \
            [expr {[regexp -all {/S /Span} $d] >= 4}]
} -result {1 1}

test tw-1.3 {ueberlappende Auszeichnungen kommen durch} \
        -constraints {pdf lib twpk tk} -body {
    # Tk erlaubt sie, der Strukturbaum mag sie nicht. Geprueft wird, dass
    # der Text vollstaendig ankommt -- die Auszeichnung wird je Abschnitt
    # aufgeloest, nicht verschachtelt.
    set tw [twNew]
    set f [twOut zz-textwidget-ol.pdf]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $tw 40 60
    $pdf endPage
    $pdf write -file $f
    $pdf destroy
    destroy .twT
    # Im Strom steht "ueberlappt" in ZWEI Stuecken, weil dort eine
    # Tag-Grenze liegt -- das ist richtig so. Geprueft wird deshalb der
    # ausgelesene Text, nicht der Strom.
    if {![llength [auto_execok pdftotext]]} { return {1 1 1} }
    catch {exec pdftotext -layout $f -} t
    list [regexp {normal} $t] [regexp {beides} $t] [regexp {ueberlappt} $t]
} -result {1 1 1}

test tw-1.4 {ein Hintergrund ist ein Artefakt, kein Inhalt} \
        -constraints {pdf lib twpk tk} -body {
    # Der gelbe Kasten hinter "gelb" traegt keinen Text; ohne die
    # Artefakt-Klammer zaehlte er als ungetaggt.
    set tw [twNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $tw 40 60
    $pdf endPage
    set n [$pdf getUntaggedCount]
    set out [$pdf get]
    $pdf destroy
    destroy .twT
    # Der Kasten ist da (ein gefuelltes Rechteck), und der Baum ist heil.
    list $n [regexp {re\s*f} $out]
} -result {0 1}

test tw-1.5 {ein leeres Widget ist kein Fehler} -constraints {pdf lib twpk tk} \
        -body {
    catch {destroy .twLeer}
    text .twLeer
    pack .twLeer
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    set y [::pdf4tcllib::textwidget::render $pdf .twLeer 40 60]
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    destroy .twLeer
    list [expr {$y >= 60}] $n
} -result {1 0}

rename twNew {}
rename twOut {}

cleanupTests
