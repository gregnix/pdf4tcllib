# test_textwidget.tcl -- Tests fuer pdf4tcllib::textwidget (pdf4tcltext)
#
# Das Modul hatte bis hierher keine einzige Testdatei. Der groessere Teil
# davon ist Tk-frei und laesst sich headless pruefen: die Umsetzung einer
# Tk-Fontspezifikation in einen PDF-Font und die Farbumrechnung. Nur die
# Tests, die wirklich ein Widget brauchen, haengen an einer Anzeige.

package require tcltest
namespace import ::tcltest::*

testConstraint text [expr {![catch {package require pdf4tcltext}]}]
testConstraint pdf  [expr {![catch {package require pdf4tcl}]}]
testConstraint tk   [expr {![catch {package require Tk}] && ![catch {
    toplevel .__probe ; destroy .__probe
}]}]

# ============================================================
# _tclFontToPdf -- Familie plus Stil auf einen der 14 Standardfonts
# ============================================================

test tw-font-1 "Helvetica ist die Vorgabe" -constraints text -body {
    ::pdf4tcllib::textwidget::_tclFontToPdf Helvetica 0 0
} -result Helvetica

test tw-font-2 "fett und kursiv" -constraints text -body {
    list [::pdf4tcllib::textwidget::_tclFontToPdf Helvetica 1 0] \
         [::pdf4tcllib::textwidget::_tclFontToPdf Helvetica 0 1] \
         [::pdf4tcllib::textwidget::_tclFontToPdf Helvetica 1 1]
} -result {Helvetica-Bold Helvetica-Oblique Helvetica-BoldOblique}

test tw-font-3 "Courier und seine Verwandten" -constraints text -body {
    set out {}
    foreach f {Courier courier "Courier New" "DejaVu Sans Mono" Consolas
               "Lucida Console"} {
        lappend out [::pdf4tcllib::textwidget::_tclFontToPdf $f 0 0]
    }
    lsort -unique $out
} -result Courier

test tw-font-4 "Times und seine Verwandten" -constraints text -body {
    set out {}
    foreach f {Times "Times New Roman" Georgia serif} {
        lappend out [::pdf4tcllib::textwidget::_tclFontToPdf $f 0 0]
    }
    lsort -unique $out
} -result Times-Roman

test tw-font-5 "unbekannte Familie faellt auf Helvetica" -constraints text -body {
    ::pdf4tcllib::textwidget::_tclFontToPdf Gibtsnicht 0 0
} -result Helvetica

test tw-font-6 "jede Kombination trifft einen echten Standardfont" \
        -constraints text -body {
    # Die 14 Standardfonts sind eine feste Liste. Ein Tippfehler in einem
    # der Rueckgabewerte faellt sonst erst auf, wenn pdf4tcl den Namen nicht
    # kennt -- also beim Erzeugen, nicht beim Uebersetzen.
    set base {Helvetica Helvetica-Bold Helvetica-Oblique Helvetica-BoldOblique
              Courier Courier-Bold Courier-Oblique Courier-BoldOblique
              Times-Roman Times-Bold Times-Italic Times-BoldItalic}
    set bad {}
    foreach fam {Helvetica Courier Times Gibtsnicht} {
        foreach b {0 1} {
            foreach i {0 1} {
                set r [::pdf4tcllib::textwidget::_tclFontToPdf $fam $b $i]
                if {$r ni $base} { lappend bad [list $fam $b $i $r] }
            }
        }
    }
    return $bad
} -result {}

# ============================================================
# _parseFont -- Tk-Fontspezifikation zerlegen
# ============================================================

test tw-parse-1 "Listenform {Familie Groesse Stil}" -constraints text -body {
    ::pdf4tcllib::textwidget::_parseFont {Helvetica 12 bold} Helvetica 10
} -result {Helvetica 12 1 0}

test tw-parse-2 "Optionsform -family -size -weight" -constraints text -body {
    ::pdf4tcllib::textwidget::_parseFont \
        {-family Times -size 14 -weight bold -slant italic} Helvetica 10
} -result {Times 14 1 1}

test tw-parse-3 "negative Groesse (Pixel) wird zum Betrag" -constraints text -body {
    lindex [::pdf4tcllib::textwidget::_parseFont {Helvetica -12} Helvetica 10] 1
} -result 12

test tw-parse-4 "leere Spezifikation nimmt die Vorgaben" -constraints text -body {
    ::pdf4tcllib::textwidget::_parseFont {} Courier 9
} -result {Courier 9 0 0}

test tw-parse-5 "oblique zaehlt wie italic" -constraints text -body {
    lindex [::pdf4tcllib::textwidget::_parseFont {Helvetica 10 oblique} \
            Helvetica 10] 3
} -result 1

# ============================================================
# _tkColorToRGB -- Tk-Farbe in PDF-Werte 0..1
# ============================================================

test tw-color-1 "sechsstellige Hexfarbe" -constraints text -body {
    set rgb [::pdf4tcllib::textwidget::_tkColorToRGB "#ff0000"]
    lmap v $rgb {format %.2f $v}
} -result {1.00 0.00 0.00}

test tw-color-2 "dreistellige Hexfarbe" -constraints text -body {
    set rgb [::pdf4tcllib::textwidget::_tkColorToRGB "#0f0"]
    lmap v $rgb {format %.2f $v}
} -result {0.00 1.00 0.00}

test tw-color-3 "Schwarz und Weiss liegen an den Grenzen" -constraints text -body {
    list [::pdf4tcllib::textwidget::_tkColorToRGB "#000000"] \
         [lmap v [::pdf4tcllib::textwidget::_tkColorToRGB "#ffffff"] \
             {format %.0f $v}]
} -result {{0.0 0.0 0.0} {1 1 1}}

test tw-color-4 "die Werte liegen zwischen 0 und 1" -constraints text -body {
    set bad {}
    foreach c {#000000 #ffffff #123456 #abc #7f7f7f} {
        foreach v [::pdf4tcllib::textwidget::_tkColorToRGB $c] {
            if {$v < 0.0 || $v > 1.0} { lappend bad [list $c $v] }
        }
    }
    return $bad
} -result {}

# ============================================================
# Optionen
# ============================================================

test tw-opts-1 "erfundene Option wird abgelehnt" -constraints {text pdf tk} -body {
    set t [text .__t1]
    $t insert end "Text"
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::textwidget::render $pdf $t 40 700 -quatsch 1} e
    $pdf destroy; destroy $t
    string match "*unknown option -quatsch*" $e
} -result 1

test tw-opts-2 "ungerade Wortzahl wird abgelehnt" -constraints {text pdf tk} -body {
    set t [text .__t2]
    $t insert end "Text"
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::textwidget::render $pdf $t 40 700 -maxwidth} e
    $pdf destroy; destroy $t
    string match "*even number*" $e
} -result 1

# ============================================================
# render -- braucht ein echtes Text-Widget
# ============================================================

test tw-render-1 "y waechst nach unten und wird zurueckgegeben" \
        -constraints {text pdf tk} -body {
    set t [text .__t3]
    $t insert end "Zeile eins\nZeile zwei\nZeile drei"
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set y2 [::pdf4tcllib::textwidget::render $pdf $t 40 100]
    $pdf destroy; destroy $t
    expr {$y2 > 100}
} -result 1

test tw-render-2 "-yvar liefert dasselbe wie der Rueckgabewert" \
        -constraints {text pdf tk} -body {
    set t [text .__t4]
    $t insert end "Eine Zeile"
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set ret [::pdf4tcllib::textwidget::render $pdf $t 40 100 -yvar yy]
    $pdf destroy; destroy $t
    expr {$ret == $yy}
} -result 1

# Ein "leeres" Text-Widget ist nicht leer: Tk haelt immer ein abschliessendes
# Newline, `$t dump -all 1.0 end` liefert `text {\n} 1.0`. render setzt
# deshalb genau eine (leere) Zeile. Gemessen, nicht angenommen -- die erste
# Fassung dieses Tests erwartete y unveraendert und war damit falsch.
test tw-render-3 "leeres Widget ergibt genau eine Zeile" \
        -constraints {text pdf tk} -body {
    set t [text .__t5]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set y2 [::pdf4tcllib::textwidget::render $pdf $t 40 100]
    $pdf destroy; destroy $t
    # eine Zeile bei Vorgabe 10 pt plus 2 pt Durchschuss
    expr {$y2 > 100 && $y2 <= 100 + 15}
} -result 1

test tw-render-4 "mehr Zeilen brauchen mehr Platz" -constraints {text pdf tk} -body {
    set ys {}
    foreach n {1 5} {
        set t [text .__t6]
        for {set i 0} {$i < $n} {incr i} { $t insert end "Zeile $i\n" }
        set pdf [::pdf4tcl::new %AUTO% -paper a4]
        $pdf startPage
        lappend ys [::pdf4tcllib::textwidget::render $pdf $t 40 100]
        $pdf destroy; destroy $t
    }
    expr {[lindex $ys 1] > [lindex $ys 0]}
} -result 1

# Tags sind der Zweck des Moduls: was im Widget fett ist, soll im PDF fett
# sein. Geprueft wird die Aufloesung, nicht das Aussehen -- dafuer braeuchte
# es einen Pixelvergleich.
test tw-render-5 "ein Tag mit eigenem Font wird aufgeloest" \
        -constraints {text pdf tk} -body {
    set t [text .__t7]
    $t tag configure fett -font {Helvetica 12 bold}
    $t insert end "normal " {} "fett" fett
    set cfg [::pdf4tcllib::textwidget::_readAllTagConfigs $t]
    destroy $t
    expr {[dict exists $cfg fett]}
} -result 1

test tw-render-6 "elidierter Text wird uebersprungen" -constraints {text pdf tk} -body {
    set ys {}
    foreach elide {0 1} {
        set t [text .__t8]
        $t tag configure weg -elide $elide
        $t insert end "sichtbar\n" {} "unsichtbar\n" weg
        set pdf [::pdf4tcl::new %AUTO% -paper a4]
        $pdf startPage
        lappend ys [::pdf4tcllib::textwidget::render $pdf $t 40 100]
        $pdf destroy; destroy $t
    }
    # Mit -elide 1 wird eine Zeile weniger gesetzt, y waechst also weniger.
    expr {[lindex $ys 1] < [lindex $ys 0]}
} -result 1

test tw-render-7 "das erzeugte PDF ist lesbar" -constraints {text pdf tk} -body {
    set out [file join [file dirname [info script]] out zz-textwidget.pdf]
    file mkdir [file dirname $out]
    set t [text .__t9]
    $t tag configure kopf -font {Helvetica 14 bold}
    $t insert end "Ueberschrift\n" kopf "Ein Absatz mit etwas Text.\n"
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 100 -maxwidth 400
    $pdf write -file $out
    $pdf destroy; destroy $t
    set size [file size $out]
    file delete $out
    expr {$size > 500}
} -result 1

cleanupTests
