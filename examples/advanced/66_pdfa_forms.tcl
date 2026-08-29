#!/usr/bin/env tclsh
# ============================================================================
# Demo 66: Formular mit Checkbox als PDF/A-2b
# ============================================================================
# Ausgabe: pdf/demo_66_pdfa_forms.pdf
#
# Lernziele:
#   - warum eine einzige Checkbox lange jedes PDF/A-Dokument zerbrach
#   - dass es zwei Ursachen waren, nicht eine
#   - wie man beides nachweist, statt es zu glauben
#
# EINE CHECKBOX WAR ZWEIMAL DAS PROBLEM.
#
# Erstens die Marke selbst. Ein Haekchen kommt ueblicherweise aus
# ZapfDingbats, und diese Schrift hat -- wie alle 14 Standardschriften --
# kein einbettbares Fontprogramm. ISO 19005 verlangt aber jedes davon in
# der Datei (Klausel 6.3.4). Eine Checkbox machte das Dokument also
# unkonform, egal was sonst stimmte. pdf4tcl 0.9.4.55 zeichnet die Marke
# seither mit Linien, sobald ein Anspruch erhoben ist.
#
# Zweitens die BESCHRIFTUNG daneben. Die kam aus CFG(fontFamily), und
# dort stand Helvetica -- dieselbe Klausel, derselbe Fehlschlag, nur eine
# Zeile weiter rechts. Behoben in pdf4tclforms 0.2.2: die Voreinstellung
# folgt jetzt fonts::init, so wie es ::pdf4tcllib::form schon tat.
#
# Gemessen vor der zweiten Korrektur, mit genau diesem Dokument:
#
#     Warnung: "the standard font Helvetica has no embeddable font
#               program, so this document will not validate as PDF/A"
#     veraPDF: FAIL 2b
#
# Danach: keine Warnung, PASS 2b.
#
# Die Probe steht am Ende dieses Skripts und laeuft mit.
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
set libDir    [file normalize [file join $scriptDir ../.. lib]]
tcl::tm::path add $libDir

package require pdf4tcl
package require pdf4tcllib
package require pdf4tclforms

# PDF/A verlangt eingebettete Fontprogramme. fonts::init sucht eine
# TrueType-Familie im System; ohne Fund kann dieses Beispiel seinen
# Anspruch nicht halten, und dann ist Schweigen besser als eine Datei,
# die etwas behauptet.
catch {::pdf4tcllib::fonts::init}
if {![::pdf4tcllib::fonts::hasTtf]} {
    puts stderr "Keine TrueType-Schrift gefunden -- Demo uebersprungen."
    exit 0
}

# Die Warnungsliste vor dem Lauf leeren, damit die Probe am Ende nur
# misst, was dieses Dokument ausgeloest hat.
set ::pdf4tcl::warnings {}

set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true -pdfa 2b]
$pdf metadata -title "Anmeldung" -author "pdf4tcllib demo"

$pdf startPage
set ctx [::pdf4tcllib::page::context a4]

$pdf setFont 16 [::pdf4tcllib::fonts::fontSansBold]
$pdf text "Anmeldung zum Seminar" -x 40 -y 50

set y 80

# --- Textfelder ------------------------------------------------------------
#
# forms::field zeichnet Beschriftung, Rahmen und das Feld selbst. Die
# Beschriftung steht seit 0.2.2 in der geladenen Schrift, nicht mehr in
# Helvetica -- das ist der Unterschied zwischen PASS und FAIL hier.
::pdf4tcllib::forms::field $pdf $ctx y {
    type text label "Name" id f_name required 1
}
::pdf4tcllib::forms::field $pdf $ctx y {
    type text label "E-Mail" id f_mail
}

# --- Die Checkbox ----------------------------------------------------------
#
# Der Fall, um den es geht. Ohne pdf4tcl 0.9.4.55 waere die Marke
# ZapfDingbats und die Datei unkonform; ohne pdf4tclforms 0.2.2 waere es
# die Beschriftung.
::pdf4tcllib::forms::checkboxLine $pdf $ctx y {
    label "Ich habe die Teilnahmebedingungen gelesen" id f_agb required 1
}
::pdf4tcllib::forms::checkboxLine $pdf $ctx y {
    label "Ich moechte den Rundbrief erhalten" id f_news
}

$pdf setFont 9 [::pdf4tcllib::fonts::fontSans]
$pdf text "Mit * gekennzeichnete Felder sind Pflichtfelder." -x 40 -y 700

$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_66_pdfa_forms.pdf]
$pdf write -file $outfile
$pdf destroy

puts "Geschrieben: $outfile"

# ============================================================================
# Die Probe
# ============================================================================
#
# Ein Beispiel, das seinen eigenen Anspruch nicht prueft, ist eine
# Behauptung. Zwei Messungen laufen hier mit; veraPDF nur, wenn es da
# ist -- ein fehlendes Werkzeug ist kein Fehlschlag.

if {[llength $::pdf4tcl::warnings]} {
    puts stderr "WARNUNGEN aus pdf4tcl:"
    foreach w $::pdf4tcl::warnings { puts stderr "  $w" }
    exit 1
}
puts "  Warnungen aus pdf4tcl: keine"

# Keine der 14 Standardschriften darf als Ressource auftauchen.
set fh [open $outfile rb]
set roh [read $fh]
close $fh
set gefunden {}
foreach std {Helvetica Times-Roman Courier Symbol ZapfDingbats} {
    if {[regexp "/BaseFont\\s*/$std\\b" $roh]} { lappend gefunden $std }
}
if {[llength $gefunden]} {
    puts stderr "Standardschrift in der Datei: [join $gefunden {, }]"
    exit 1
}
puts "  Standardschriften in der Datei: keine"

if {[llength [auto_execok verapdf]]} {
    catch {exec verapdf --format text $outfile} res
    if {[string match "PASS*2b*" $res]} {
        puts "  veraPDF: PASS 2b"
    } else {
        puts stderr "  veraPDF: $res"
        exit 1
    }
} else {
    puts "  veraPDF nicht im PATH -- uebersprungen."
    puts "  Von Hand:  verapdf -f 2b $outfile"
}
