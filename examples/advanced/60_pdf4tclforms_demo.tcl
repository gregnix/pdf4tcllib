#!/usr/bin/env tclsh
# 60_pdf4tclforms_demo.tcl -- Ausfuellbare PDF-Formulare per Spec
#
# Erzeugt vier Beispiel-PDFs:
#   demo_60_anrufernotiz.pdf
#   demo_60_pc_inventar.pdf
#   demo_60_teilnehmerliste.pdf
#   demo_60_bestellformular.pdf

set scriptDir [file dirname [file normalize [info script]]]
set libDir    [file normalize [file join $scriptDir ../.. lib]]
tcl::tm::path add $libDir

set oldTm [file join $libDir pdf4tclforms-0.1.tm]
if {[file exists $oldTm]} {
    puts stderr "Konflikt: $oldTm noch vorhanden (Version 0.1 im Dateinamen)."
    puts stderr "Entfernen und nur pdf4tclforms-0.1.1.tm behalten:"
    puts stderr "  rm $oldTm"
    exit 1
}

package require pdf4tclforms 0.1.1
if {[info procs ::pdf4tcllib::forms::_addForm] eq ""} {
    puts stderr "pdf4tclforms ohne _addForm — falsche oder alte Datei in $libDir"
    exit 1
}
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir

proc writeForm {basename spec} {
    global outdir
    set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf startPage
    set y [dict get $ctx top]
    pdf4tclforms::renderSchema $pdf $ctx $spec -yvar y
    set out [file join $outdir $basename]
    $pdf endPage
    $pdf write -file $out
    $pdf destroy
    puts "  $out"
}

puts "pdf4tclforms Demo:"
writeForm demo_60_anrufernotiz.pdf \
    [pdf4tclforms::template callnote]
writeForm demo_60_pc_inventar.pdf \
    [pdf4tclforms::template inventory]
writeForm demo_60_teilnehmerliste.pdf \
    [pdf4tclforms::template checklist -title "Teilnehmerliste" -emptyRows 25]
writeForm demo_60_bestellformular.pdf \
    [pdf4tclforms::template order]

puts "Fertig. Im PDF-Reader ausfuellen und speichern."
