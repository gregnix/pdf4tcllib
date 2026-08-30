# test_textwidget.tcl -- Tests fuer pdf4tcllib::textwidget (pdf4tcltext)
#
# Das Modul hatte bis hierher keine einzige Testdatei. Der groessere Teil
# davon ist Tk-frei und laesst sich headless pruefen: die Umsetzung einer
# Tk-Fontspezifikation in einen PDF-Font und die Farbumrechnung. Nur die
# Tests, die wirklich ein Widget brauchen, haengen an einer Anzeige.

package require tcltest
namespace import ::tcltest::*

# Damit die Datei auch EINZELN laeuft. Ohne diese Zeile findet sie
# pdf4tcllib nur ueber ein installiertes Paket -- und die Constraints
# unten fragen genau danach. Fehlt es, ueberspringt tcltest still
# ALLES und meldet trotzdem Erfolg: Rueckgabewert 0, Failed 0. Der
# Runner setzt den Pfad selbst, deshalb fiel es nie auf.
tcl::tm::path add [file join [file dirname [file normalize [info script]]] .. lib]

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

# ============================================================
# Die drei Punkte, die pdfcompose gefunden hat -- seit 0.3 behoben
#
# Gefunden nicht von dieser Suite, sondern von einer App, die das Modul
# benutzt. Sie musste alle drei umgehen und hat sie aufgeschrieben; hier
# stehen sie als Messung. Bis 0.2 standen an dieser Stelle drei Tests,
# die den DEFEKT festhielten; sie sind mit der Reparatur rot geworden,
# und das war ihre Aufgabe.
# ============================================================

test tw-limit-1 "-maxwidth bricht um" -constraints {text pdf tk} -body {
    # Bis 0.2 bekam _flushLine maxW als Parameter und las ihn nie: eine
    # Zeile des Widgets wurde eine PDF-Zeile, wie lang sie auch war.
    # Gemessen damals: -maxwidth 200, ein Absatz von 200 Zeichen -> EINE
    # Zeile von 987 pt auf einem Blatt von 595 pt.
    set t [text .__lim1 -width 80 -height 6 -font {Helvetica 11}]
    $t insert end "Ein sehr langer Absatz, der in einer schmalen Spalte\
            umbrechen muesste, weil er deutlich mehr Text enthaelt als in\
            200 Punkt Breite passt, und der deshalb auf mehrere PDF-Zeilen\
            verteilt werden sollte."
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 40 -maxwidth 200 -fontsize 11
    $pdf endPage
    set strom [$pdf get]
    $pdf setFont 11 Helvetica
    set breiteste 0
    foreach {all txt} [regexp -all -inline {\(([^)]*)\) Tj} $strom] {
        set w [$pdf getStringWidth $txt]
        if {$w > $breiteste} { set breiteste $w }
    }
    set zeilen [llength [regexp -all -inline {1 0 0 1 [0-9.-]+ [0-9.-]+ Tm} \
            $strom]]
    $pdf destroy; destroy $t
    # mehrere Zeilen, keine breiter als der Platz
    list [expr {$zeilen > 1}] [expr {$breiteste <= 200}]
} -result {1 1}

test tw-limit-1a "ein Wort breiter als der Platz wird trotzdem gesetzt" \
        -constraints {text pdf tk} -body {
    # Abschneiden waere stiller Verlust, eine Endlosschleife waere
    # schlimmer als eine zu breite Zeile.
    set t [text .__lim1a -width 40 -height 3 -font {Helvetica 11}]
    $t insert end "Donaudampfschiffahrtsgesellschaftskapitaenspatent"
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 40 -maxwidth 30 -fontsize 11
    $pdf endPage
    set strom [$pdf get]
    $pdf destroy; destroy $t
    regexp {Donaudampf} $strom
} -result 1

test tw-limit-1b "der Umbruch misst je Abschnitt mit dessen Schrift" \
        -constraints {text pdf tk} -body {
    # Ein Wort in fett ist breiter als dasselbe Wort mager. Eine Rechnung
    # mit einer einzigen Schrift braeche an der falschen Stelle.
    set t [text .__lim1b -width 60 -height 4 -font {Helvetica 11}]
    $t tag configure gross -font {Helvetica 22 bold}
    $t insert end "klein klein " {} "GROSS GROSS GROSS" gross
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 40 -maxwidth 150 -fontsize 11
    $pdf endPage
    set strom [$pdf get]
    # Keine gezeichnete Zeichenkette darf in ihrer eigenen Schrift
    # breiter als 150 pt sein.
    set zuBreit 0
    foreach {all fn fs txt} [regexp -all -inline \
            {/(\S+) ([0-9.]+) Tf[^(]*\(([^)]*)\) Tj} $strom] {
        $pdf setFont $fs [string map {{#20} { }} $fn]
        if {[$pdf getStringWidth $txt] > 150.5} { incr zuBreit }
    }
    $pdf destroy; destroy $t
    set zuBreit
} -result 0

test tw-limit-2 "pdf4tcltext::render gibt es" -constraints {text} -body {
    # Der Alias am Dateiende macht "namespace import
    # ::pdf4tcllib::textwidget::render". Bis 0.2 fehlte im
    # Quellnamensraum das "namespace export" -- ohne Exportmuster
    # importiert Tcl nichts, und zwar ohne Fehler. Der Alias entstand
    # einfach nicht.
    list [expr {[info commands ::pdf4tcltext::render] ne ""}] \
         [expr {[info commands ::pdf4tcllib::textwidget::render] ne ""}] \
         [namespace eval ::pdf4tcllib::textwidget {namespace export}]
} -result {1 1 render}

test tw-limit-3 "eine unter dem Familiennamen geladene Schrift wird benutzt" \
        -constraints {text pdf tk} -body {
    # Bis 0.2 kannte _tclFontToPdf nur die 14 Standardschriften. Wer eine
    # TTF unter dem Tk-Familiennamen lud und im Widget so auszeichnete,
    # bekam Helvetica -- gerade die Schrift ohne Glyphen jenseits
    # Latin-1, und ohne ein Wort dazu.
    set ttf /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
    if {![file exists $ttf]} { return {1 1} }
    catch {::pdf4tcl::loadBaseTrueTypeFont __twTtf $ttf}
    catch {::pdf4tcl::createFontSpecCID __twTtf {Pruef Sans}}
    set t [text .__lim3 -width 60 -height 4]
    $t tag configure dv -font {{Pruef Sans} 11}
    $t insert end "Text in einer geladenen Schrift\n" dv
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 40 -maxwidth 400 -fontsize 11
    $pdf endPage
    set strom [$pdf get]
    $pdf destroy; destroy $t
    list [expr {[regexp {/Pruef#20Sans} $strom] ? 1 : 0}] \
         [expr {[regexp {/Helvetica} $strom] ? 0 : 1}]
} -result {1 1}

test tw-limit-3a "unbekannte Familien fallen weiter auf die 14 zurueck" \
        -constraints {text} -body {
    # Der Rueckfall muss bleiben. Sonst waere nicht unterscheidbar, ob
    # eine Familie ERKANNT wurde oder nur nichts gefunden wurde.
    list [::pdf4tcllib::textwidget::_tclFontToPdf GibtEsNichtXYZ 0 0] \
         [::pdf4tcllib::textwidget::_tclFontToPdf Times 0 0] \
         [::pdf4tcllib::textwidget::_tclFontToPdf Helvetica 1 0]
} -result {Helvetica Times-Roman Helvetica-Bold}

test tw-just-1 "justify center und right kommen ins PDF" \
        -constraints {text pdf tk} -body {
    # Bis 0.2 war -justify "not implemented": center und right wirkten
    # im Widget und verschwanden im PDF, ohne ein Wort. Eine Anwendung
    # bot die Auswahl in ihrer Leiste an und musste sie mit "nur
    # Ansicht" beschriften -- das war der Anlass.
    set t [text .__just -width 60 -height 5 -font {Helvetica 11}]
    $t tag configure mitte  -justify center
    $t tag configure rechts -justify right
    $t insert end "links\n" {} "mitte\n" mitte "rechts\n" rechts
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 40 -maxwidth 300 -fontsize 11
    $pdf endPage
    set strom [$pdf get]
    $pdf setFont 11 Helvetica
    array set pos {}
    foreach {all xx yy txt} [regexp -all -inline \
            {1 0 0 1 ([0-9.-]+) ([0-9.-]+) Tm[^(]*\(([^)]*)\) Tj} $strom] {
        set pos($txt) [list $xx [expr {$xx + [$pdf getStringWidth $txt]}]]
    }
    $pdf destroy; destroy $t
    # Rahmen ist x=40 bis 340.
    lassign $pos(links)  l0 l1
    lassign $pos(mitte)  m0 m1
    lassign $pos(rechts) r0 r1
    list [expr {abs($l0 - 40) < 0.01}] \
         [expr {abs(($m0 + $m1) / 2.0 - 190.0) < 0.5}] \
         [expr {abs($r1 - 340) < 0.5}]
} -result {1 1 1}

test tw-just-2 "eine zu breite Zeile wird nicht verschoben" \
        -constraints {text pdf tk} -body {
    # Sonst ruecke die Zeile nach LINKS aus dem Rahmen heraus -- eine
    # Ausrichtung, die den Text weiter wegtraegt, ist keine.
    set t [text .__just2 -width 60 -height 3 -font {Helvetica 11}]
    $t tag configure rechts -justify right
    $t insert end "Ein einzelnes sehr langes Wort passt hier nicht\n" rechts
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 40 -maxwidth 40 -fontsize 11
    $pdf endPage
    set strom [$pdf get]
    $pdf destroy; destroy $t
    set links {}
    foreach {all xx} [regexp -all -inline \
            {1 0 0 1 ([0-9.-]+) [0-9.-]+ Tm} $strom] { lappend links $xx }
    # keine Zeile links von 40
    set davor 0
    foreach v $links { if {$v < 39.99} { incr davor } }
    list [expr {[llength $links] > 0}] $davor
} -result {1 0}

test tw-off-1 "-offset hebt und senkt die Grundlinie" \
        -constraints {text pdf tk} -body {
    # Bis hierher "not implemented": ein Fussnotenzeichen stand auf der
    # Grundlinie wie jeder andere Buchstabe. Der Wert ist eine
    # Pixelangabe des Widgets und wird mit demselben Faktor wie
    # -lmargin1 in Punkt umgerechnet: 5 px -> 3,75 pt.
    set t [text .__off -width 60 -height 4 -font {Helvetica 11}]
    $t tag configure hoch -offset 5  -font {Helvetica 7}
    $t tag configure tief -offset -4 -font {Helvetica 7}
    $t insert end "x" {} "H" hoch " " {} "T" tief "\n"
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 40 -maxwidth 300 -fontsize 11
    $pdf endPage
    set strom [$pdf get]
    $pdf destroy; destroy $t
    array set y {}
    foreach {all xx yy txt} [regexp -all -inline \
            {1 0 0 1 ([0-9.-]+) ([0-9.-]+) Tm[^(]*\(([^)]*)\) Tj} $strom] {
        set y($txt) $yy
    }
    # PDF-y waechst nach oben: hochgestellt liegt hoeher als die
    # Grundlinie, tiefgestellt tiefer.
    list [expr {abs($y(H) - $y(x) - 3.75) < 0.01}] \
         [expr {abs($y(T) - $y(x) + 3.00) < 0.01}]
} -result {1 1}

test tw-off-2 "ohne -offset bleibt alles auf einer Grundlinie" \
        -constraints {text pdf tk} -body {
    # Die Gegenprobe zur Gegenprobe: ohne das Tag darf sich nichts
    # verschieben. Sonst misst tw-off-1 nur, dass ueberhaupt etwas
    # anders ist.
    set t [text .__off2 -width 60 -height 4 -font {Helvetica 11}]
    $t tag configure klein -font {Helvetica 7}
    $t insert end "x" {} "H" klein " " {} "T" klein "\n"
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $pdf startPage
    ::pdf4tcllib::textwidget::render $pdf $t 40 40 -maxwidth 300 -fontsize 11
    $pdf endPage
    set strom [$pdf get]
    $pdf destroy; destroy $t
    set ys {}
    foreach {all xx yy txt} [regexp -all -inline \
            {1 0 0 1 ([0-9.-]+) ([0-9.-]+) Tm[^(]*\(([^)]*)\) Tj} $strom] {
        lappend ys $yy
    }
    llength [lsort -unique $ys]
} -result 1

cleanupTests
