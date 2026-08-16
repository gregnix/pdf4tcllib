# test_toc.tcl -- Tests fuer pdf4tcllib::toc
#
# Die Frage, an der ein Inhaltsverzeichnis haengt, ist nicht das Zeichnen,
# sondern ob die Zahlen stimmen. Deshalb pruefen die wichtigen Tests hier
# nicht die Prozedur, sondern die erzeugte Datei: sie lesen mit pdftotext
# nach, auf welcher Seite eine Ueberschrift wirklich steht, und vergleichen
# das mit dem, was das Verzeichnis behauptet.

package require tcltest
namespace import ::tcltest::*

testConstraint toc [expr {![catch {package require pdf4tcltoc}]}]
testConstraint pdf [expr {![catch {package require pdf4tcl}]}]
testConstraint pdftotext [expr {[llength [auto_execok pdftotext]] > 0}]

proc tocOut {} {
    set d [file join [file dirname [info script]] out]
    file mkdir $d
    return [file join $d zz-toc.pdf]
}

# Ein Dokument mit fuenf Kapiteln, jedes lang genug fuer Seitenumbrueche.
proc tocBuild {args} {
    set out [tocOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set body [string repeat "Lorem ipsum dolor sit amet, consetetur\
            sadipscing elitr, sed diam nonumy eirmod tempor invidunt. " 4]
    set res [::pdf4tcllib::toc::document $pdf a4 {
        set x [dict get $ctx left]
        set w [dict get $ctx text_w]
        $pdf startPage
        set y [dict get $ctx top]
        foreach kap {Einleitung Grundlagen Aufbau Betrieb Anhang} {
            ::pdf4tcllib::toc::heading $pdf $ctx y 1 $kap
            for {set i 0} {$i < 5} {incr i} {
                set y [::pdf4tcllib::text::writeParagraph $pdf $body $x $y $w 11]
                ::pdf4tcllib::page::_advance $ctx y 8
                if {$y > [dict get $ctx bottom] - 80} {
                    $pdf endPage
                    $pdf startPage
                    set y [dict get $ctx top]
                }
            }
        }
        $pdf endPage
    } {*}$args]
    $pdf write -file $out
    $pdf destroy
    return $res
}

# Auf welcher Seite steht diese Ueberschrift wirklich?
proc tocPageOf {title} {
    set out [tocOut]
    set n 0
    catch {set n [exec pdfinfo $out]}
    regexp {Pages:\s+(\d+)} $n -> total
    for {set p 1} {$p <= $total} {incr p} {
        set txt ""
        catch {set txt [exec pdftotext -f $p -l $p $out -]}
        foreach line [split $txt \n] {
            if {[string trim $line] eq $title} { return $p }
        }
    }
    return 0
}

# ============================================================
# Sammeln
# ============================================================

test toc-collect-1 "collect liefert Ebene, Titel und Seite" \
        -constraints {toc pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    set e [::pdf4tcllib::toc::collect {
        $pdf startPage
        set y [dict get $ctx top]
        ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Erstes"
        $pdf endPage
        $pdf startPage
        set y [dict get $ctx top]
        ::pdf4tcllib::toc::heading $pdf $ctx y 2 "Zweites"
        $pdf endPage
    }]
    $pdf destroy
    return $e
} -result {{1 Erstes 1} {2 Zweites 2}}

test toc-collect-2 "ausserhalb von collect wird nichts gesammelt" \
        -constraints {toc pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set y [dict get $ctx top]
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Nicht gesammelt"
    $pdf destroy
    ::pdf4tcllib::toc::entries
} -result {{1 Erstes 1} {2 Zweites 2}}

test toc-collect-3 "ein Fehler im Skript schaltet das Sammeln wieder ab" \
        -constraints {toc pdf} -body {
    catch {::pdf4tcllib::toc::collect {error "geplatzt"}}
    # Wenn COLLECT haengengeblieben waere, wuerde die naechste heading
    # ausserhalb eines Laufs Eintraege anhaengen.
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set y [dict get $ctx top]
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Danach"
    set n [llength [::pdf4tcllib::toc::entries]]
    $pdf destroy
    return $n
} -result 0

test toc-heading-1 "ungueltige Ebene wird abgelehnt" -constraints {toc pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set y [dict get $ctx top]
    catch {::pdf4tcllib::toc::heading $pdf $ctx y 9 "Zu tief"} e
    $pdf destroy
    string match "*level must be 1..6*" $e
} -result 1

test toc-heading-2 "unbekannte Option wird abgelehnt" -constraints {toc pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set y [dict get $ctx top]
    catch {::pdf4tcllib::toc::heading $pdf $ctx y 1 "X" -quatsch 1} e
    $pdf destroy
    string match "*unknown option -quatsch*" $e
} -result 1

test toc-heading-3 "eine Ueberschrift schiebt y nach unten" -constraints {toc pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set y [dict get $ctx top]
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Kapitel"
    $pdf destroy
    expr {$y > [dict get [::pdf4tcllib::page::context a4] top]}
} -result 1

# ============================================================
# Seitenzahl der Verzeichnisseiten
# ============================================================

test toc-count-1 "keine Eintraege, keine Seite" -constraints toc -body {
    ::pdf4tcllib::toc::pageCount [::pdf4tcllib::page::context a4] {}
} -result 0

test toc-count-2 "wenige Eintraege passen auf eine Seite" -constraints toc -body {
    set e {}
    foreach t {A B C D E} { lappend e [list 1 $t 3] }
    ::pdf4tcllib::toc::pageCount [::pdf4tcllib::page::context a4] $e
} -result 1

test toc-count-3 "viele Eintraege brauchen mehrere Seiten" -constraints toc -body {
    set e {}
    for {set i 0} {$i < 120} {incr i} { lappend e [list 1 "Kapitel $i" 3] }
    expr {[::pdf4tcllib::toc::pageCount [::pdf4tcllib::page::context a4] $e] > 1}
} -result 1

# Der Waechter, der in der ersten Fassung dieses Moduls sofort ansprang:
# pageCount und render muessen dieselbe Zahl liefern, sonst zeigt jede
# Zahl im Verzeichnis auf die falsche Seite.
test toc-count-4 "pageCount und render sind sich einig, bei jeder Laenge" \
        -constraints {toc pdf} -body {
    set ctx [::pdf4tcllib::page::context a4]
    set bad {}
    foreach n {1 5 40 43 44 45 90 120} {
        set e {}
        for {set i 0} {$i < $n} {incr i} { lappend e [list 1 "Kapitel $i" 7] }
        set want [::pdf4tcllib::toc::pageCount $ctx $e]
        set pdf [::pdf4tcl::new %AUTO% -paper a4]
        set got [::pdf4tcllib::toc::render $pdf $ctx $e]
        $pdf destroy
        if {$want != $got} { lappend bad [list $n want $want got $got] }
    }
    return $bad
} -result {}

# ============================================================
# Der ganze Lauf -- und die Probe aufs Exempel
# ============================================================

test toc-doc-1 "document liefert Eintraege, Verzeichnis- und Inhaltsseiten" \
        -constraints {toc pdf} -body {
    set res [tocBuild -title "Inhalt"]
    list [llength [dict get $res entries]] \
         [expr {[dict get $res tocPages] >= 1}] \
         [expr {[dict get $res contentPages] >= 1}]
} -result {5 1 1}

test toc-doc-2 "die Seitenzahlen im Verzeichnis stimmen mit der Wirklichkeit" \
        -constraints {toc pdf pdftotext} -body {
    set res [tocBuild -title "Inhalt"]
    set bad {}
    foreach e [dict get $res entries] {
        lassign $e level title page
        set real [tocPageOf $title]
        if {$real != $page} { lappend bad [list $title behauptet $page steht_auf $real] }
    }
    return $bad
} -result {}

test toc-doc-3 "das Verzeichnis steht vorn" -constraints {toc pdf pdftotext} -body {
    tocBuild -title "Inhaltsverzeichnis"
    set txt ""
    catch {set txt [exec pdftotext -f 1 -l 1 [tocOut] -]}
    string match "*Inhaltsverzeichnis*" $txt
} -result 1

test toc-doc-4 "jeder Titel taucht im Verzeichnis auf" \
        -constraints {toc pdf pdftotext} -body {
    tocBuild
    set txt ""
    catch {set txt [exec pdftotext -f 1 -l 1 [tocOut] -]}
    set missing {}
    foreach t {Einleitung Grundlagen Aufbau Betrieb Anhang} {
        if {![string match "*$t*" $txt]} { lappend missing $t }
    }
    return $missing
} -result {}

test toc-doc-5 "Lesezeichen entstehen, eines je Ueberschrift" \
        -constraints {toc pdf} -body {
    tocBuild
    set fh [open [tocOut] rb]
    fconfigure $fh -encoding iso8859-1 -translation binary
    set d [read $fh]
    close $fh
    llength [regexp -all -inline {/Title\s*\(} $d]
} -result 5

# Der Kern des Zwei-Pass-Verfahrens: das Skript LAEUFT zweimal, sein
# Inhalt darf aber nur einmal im Dokument stehen. Der erste Lauf geht in
# ein Wegwerf-Dokument.
#
# Gezaehlt wird die Ueberschrift als eigene Zeile. Die Verzeichniszeile
# zaehlt nicht mit, weil dort Fuehrungspunkte und Seitenzahl in derselben
# Zeile stehen -- meine erste Fassung dieses Tests hat genau das uebersehen
# und 2 erwartet.
test toc-doc-6 "das Skript laeuft zweimal, der Inhalt steht einmal im PDF" \
        -constraints {toc pdf pdftotext} -body {
    tocBuild
    set txt ""
    catch {set txt [exec pdftotext [tocOut] -]}
    set asHeading 0
    set inToc 0
    foreach line [split $txt \n] {
        set l [string trim $line]
        if {$l eq "Einleitung"} { incr asHeading ; continue }
        if {[string match "Einleitung*" $l] && [regexp {[0-9]$} $l]} { incr inToc }
    }
    list $asHeading $inToc
} -result {1 1}

test toc-doc-7 "unbekannte Option wird abgelehnt" -constraints {toc pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    catch {::pdf4tcllib::toc::document $pdf a4 {} -quatsch 1} e
    $pdf destroy
    string match "*unknown option -quatsch*" $e
} -result 1

cleanupTests
