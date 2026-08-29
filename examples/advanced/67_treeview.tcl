#!/usr/bin/env wish
# ============================================================================
# Demo 67: ttk::treeview nach PDF -- als Tabelle und als Gliederung
# ============================================================================
# Ausgabe: pdf/demo_67_treeview.pdf
#
# Lernziele:
#   - warum ein treeview ZWEI Ausgaben hat und nicht eine mit Schalter
#   - dass ein geschlossener Ast geschlossen bleibt
#   - was das fuer den Strukturbaum bedeutet
#
# EIN TREEVIEW IST ZWEIERLEI ZUGLEICH: eine Tabelle mit Spalten und ein
# Baum. Auf dem Schirm sieht man beides gleichzeitig; im PDF muss man
# sich entscheiden, denn der Strukturbaum kennt kein Zwitterwesen:
#
#   Tabelle     Table / TR / TD      Zellen, Kopfzeilen, Spaltenbezug
#   Gliederung  L / LI / LBody       Punkte, Unterpunkte
#
# Was von beidem gilt, kann die Bibliothek nicht erraten -- ein treeview
# mit drei Wertespalten ist eine Tabelle, einer mit nur der Baumspalte
# eine Liste. Deshalb zwei Prozeduren statt einer Option.
#
# Seite 1 zeigt render (Tabelle), Seite 2 outline (Gliederung mit
# Lesezeichen).

package require Tk

set scriptDir [file dirname [file normalize [info script]]]
set libDir    [file normalize [file join $scriptDir ../.. lib]]
tcl::tm::path add $libDir

package require pdf4tcl
package require pdf4tcllib
package require pdf4tcltreeview

catch {::pdf4tcllib::fonts::init}

# ---------------------------------------------------------------------------
# Das Widget
# ---------------------------------------------------------------------------
ttk::treeview .tv -columns {menge preis summe} -show {tree headings} \
        -height 12
.tv heading #0     -text "Artikel"
.tv heading menge  -text "Menge"
.tv heading preis  -text "Einzelpreis"
.tv heading summe  -text "Betrag"
.tv column menge -anchor e -width 70
.tv column preis -anchor e -width 90
.tv column summe -anchor e -width 90
.tv column #0 -width 220

set schrauben [.tv insert {} end -text "Schrauben" -values {{} {} 49,00} -open 1]
.tv insert $schrauben end -text "M6 x 20"  -values {60 0,49 29,40}
.tv insert $schrauben end -text "M8 x 30"  -values {40 0,49 19,60}

set muttern [.tv insert {} end -text "Muttern" -values {{} {} 36,00} -open 1]
.tv insert $muttern end -text "M6" -values {200 0,18 36,00}

# Dieser Ast ist ZU. Das PDF zeigt, was zu sehen war -- der Inhalt taucht
# auf Seite 1 nicht auf. Auf Seite 2 steht er, weil dort -all 1 gesetzt
# ist; so laesst sich der Unterschied nebeneinander sehen.
set scheiben [.tv insert {} end -text "Unterlegscheiben" -values {500 0,04 20,00} -open 0]
.tv insert $scheiben end -text "M6, verzinkt" -values {300 0,04 12,00}
.tv insert $scheiben end -text "M8, verzinkt" -values {200 0,04 8,00}

pack .tv -fill both -expand 1
update idletasks

# ---------------------------------------------------------------------------
# Das Dokument
# ---------------------------------------------------------------------------
set pdf [pdf4tcl::new %AUTO% -paper a4 -margin 40 -orient 1]
$pdf tagged 1 -lang de-DE
$pdf metadata -title "Bestellpositionen" -author "pdf4tcllib demo"

# --- Seite 1: als Tabelle --------------------------------------------------
$pdf startPage
$pdf setFont 14 [::pdf4tcllib::fonts::fontSansBold]
$pdf tagText H1 "Als Tabelle" -x 0 -y 10

$pdf setFont 9 [::pdf4tcllib::fonts::fontSans]
$pdf tagBegin P
$pdf text "render zeichnet, was auf dem Schirm steht: die Baumspalte\
        eingerueckt, die Wertespalten daneben. Der geschlossene Ast bleibt\
        zu." -x 0 -y 34
$pdf tagEnd

set y 60
::pdf4tcllib::treeview::render $pdf .tv 0 $y -maxwidth 500 -yvar y \
        -summary "Bestellpositionen nach Artikelgruppen, mit Menge,\
                Einzelpreis und Betrag"

$pdf setFont 8 [::pdf4tcllib::fonts::fontSans]
$pdf tagBegin P
$pdf text "Ungetaggte Zeichenbefehle bis hier: [$pdf getUntaggedCount]" \
        -x 0 -y [expr {$y + 16}]
$pdf tagEnd
$pdf endPage

# --- Seite 2: als Gliederung -----------------------------------------------
$pdf startPage
$pdf setFont 14 [::pdf4tcllib::fonts::fontSansBold]
$pdf tagText H1 "Als Gliederung" -x 0 -y 10

$pdf setFont 9 [::pdf4tcllib::fonts::fontSans]
$pdf tagBegin P
$pdf text "outline nimmt nur die Baumspalte und setzt je Knoten ein\
        Lesezeichen -- damit ist der Baum im Leser navigierbar, was eine\
        Tabelle nicht leistet. Hier mit -all 1, also samt geschlossenem\
        Ast." -x 0 -y 34
$pdf tagEnd

set y2 [::pdf4tcllib::treeview::outline $pdf .tv 0 70 -all 1 -fontsize 11 \
        -indentW 18]

$pdf setFont 8 [::pdf4tcllib::fonts::fontSans]
$pdf tagBegin P
$pdf text "Ungetaggte Zeichenbefehle: [$pdf getUntaggedCount]" \
        -x 0 -y [expr {$y2 + 16}]
$pdf tagEnd
$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_67_treeview.pdf]
$pdf write -file $outfile
set offen [$pdf getUntaggedCount]
$pdf destroy

puts "Geschrieben: $outfile"
if {$offen != 0} {
    puts stderr "  $offen Zeichenbefehle ausserhalb des Strukturbaums"
    exit 1
}
puts "  ausserhalb des Strukturbaums: nichts"
exit 0
