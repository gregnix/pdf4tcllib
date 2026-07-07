#!/usr/bin/env tclsh
# 61_pdf4tclforms_schema.tcl -- Eigenes Formular-Schema (ohne template)
#
# Zeigt die Spec-Struktur von pdf4tclforms::renderSchema:
#   title, sections -> { title, fields, table, sums }
#   fields -> Einzelfeld, row, separator, table, sums
#
# Ausgabe: pdf/demo_61_wartungsprotokoll.pdf

set scriptDir [file dirname [file normalize [info script]]]
set libDir    [file normalize [file join $scriptDir ../.. lib]]
tcl::tm::path add $libDir

package require pdf4tclforms 0.1.1
package require pdf4tcl

# Eigenes Schema als Proc (analog zu template, aber lokal / projektspezifisch).
proc schemaWartungsprotokoll {args} {
    array set o {
        -title     "Wartungsprotokoll"
        -emptyRows 6
    }
    array set o $args

    return [dict create \
        title $o(-title) \
        sections [dict create \
            auftrag [dict create \
                title "Auftrag" \
                fields {
                    {row {
                        {id f_datum type text label "Datum:" width 120 init ""}
                        {id f_zeit  type text label "Uhrzeit:" width 100 init ""}
                    }}
                    {id f_nr    type text label "Auftragsnr.:" required 1}
                    {id f_ort   type text label "Kunde / Standort:"}
                    {id f_kontakt type text label "Ansprechpartner:"}
                }] \
            geraet [dict create \
                title "Geraet" \
                fields {
                    {id f_typ type combobox label "Geraetetyp:" \
                        options {PC Drucker Netzwerk Server Sonstiges}}
                    {id f_inv   type text label "Inventarnr.:"}
                    {id f_ser   type text label "Seriennummer:"}
                    {separator 6}
                    {id f_fehler type text label "Fehlerbeschreibung:" \
                        multiline 1 fieldh 55}
                }] \
            arbeit [dict create \
                title "Arbeitsschritte" \
                table [dict create \
                    headers   {Nr Taetigkeit Ergebnis} \
                    widths    {25 250 170} \
                    emptyRows $o(-emptyRows) \
                    editable  1 \
                    idPrefix  f_step] \
                fields {
                    {separator 4}
                    {id f_ok type checkbox label "Geraet wieder betriebsbereit" init false}
                    {id f_nach type text label "Offene Punkte / Nacharbeit:" \
                        multiline 1 fieldh 45}
                }] \
            abschluss [dict create \
                title "Abschluss" \
                fields {
                    {row {
                        {id f_dauer type text label "Dauer (h):" width 90 init ""}
                        {id f_mat   type text label "Material:" width 210 init ""}
                    }}
                    {id f_tech type text label "Techniker:" required 1}
                    {id f_unterschrift type text label "Unterschrift (Name):"}
                }]]]
}

# Minimalbeispiel (inline, ohne Proc):
#   set spec [dict create title "Kurz-Checkliste" sections [dict create \
#       main [dict create title "Eintrag" fields {
#           {id f_name type text label "Name:" required 1}
#           {id f_ok type checkbox label "Erledigt" init false}
#       }]]]
#   pdf4tclforms::renderSchema $pdf $ctx $spec -yvar y

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

set y [dict get $ctx top]
pdf4tclforms::renderSchema $pdf $ctx [schemaWartungsprotokoll] -yvar y

set outfile [file join $outdir demo_61_wartungsprotokoll.pdf]
$pdf endPage
$pdf write -file $outfile
$pdf destroy

puts "Eigenes Schema -> $outfile"
exit 0
