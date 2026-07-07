#!/usr/bin/env tclsh
# 62_pdf4tclforms_fehlermeldung.tcl -- Fehlermeldung als eigenes Schema
#
# Ausfuellbares Formular fuer Software-/System-Fehler:
#   Melder, betroffenes System, Beschreibung, Reproduktion, IT-Bearbeitung
#
# Ausgabe: pdf/demo_62_fehlermeldung.pdf

set scriptDir [file dirname [file normalize [info script]]]
set libDir    [file normalize [file join $scriptDir ../.. lib]]
tcl::tm::path add $libDir

package require pdf4tclforms 0.1.1
package require pdf4tcl

proc schemaFehlermeldung {args} {
    array set o {-title "Fehlermeldung"}
    array set o $args

    return [dict create \
        title $o(-title) \
        sections [dict create \
            meldung [dict create \
                title "Meldung" \
                fields {
                    {row {
                        {id f_datum type text label "Datum:" width 120 init ""}
                        {id f_zeit  type text label "Uhrzeit:" width 100 init ""}
                    }}
                    {id f_melder type text label "Gemeldet von:" required 1}
                    {id f_abteil type text label "Abteilung / Team:"}
                    {id f_kontakt type text label "Erreichbar (Tel/E-Mail):"}
                }] \
            system [dict create \
                title "Betroffenes System" \
                fields {
                    {id f_system type text label "System / Anwendung:" required 1}
                    {row {
                        {id f_version type text label "Version:" width 120 init ""}
                        {id f_host   type text label "Rechner/Host:" width 200 init ""}
                    }}
                    {id f_prio type combobox label "Prioritaet:" \
                        options {Niedrig Normal Hoch Kritisch} init Normal}
                    {id f_haeufig type combobox label "Haeufigkeit:" \
                        options {Einmalig Gelegentlich Haeufig Immer} init Einmalig}
                }] \
            fehler [dict create \
                title "Fehlerbeschreibung" \
                fields {
                    {id f_kurz type text label "Kurzbeschreibung:" required 1}
                    {separator 4}
                    {id f_schritte type text label "Schritte zur Reproduktion:" \
                        multiline 1 fieldh 70}
                    {id f_erwartet type text label "Erwartetes Verhalten:" \
                        multiline 1 fieldh 45}
                    {id f_ist type text label "Tatsaechliches Verhalten:" \
                        multiline 1 fieldh 45}
                }] \
            anhang [dict create \
                title "Anlagen / Zusatz" \
                fields {
                    {id f_screenshot type checkbox \
                        label "Screenshot oder Anhang liegt bei" init false}
                    {id f_log type checkbox \
                        label "Logdatei / Fehlermeldung (Text) vorhanden" init false}
                    {id f_logpfad type text label "Pfad / Dateiname:"}
                    {id f_bem type text label "Sonstige Hinweise:" \
                        multiline 1 fieldh 40}
                }] \
            bearbeitung [dict create \
                title "Bearbeitung (IT)" \
                fields {
                    {row {
                        {id f_ticket type text label "Ticket-Nr.:" width 120 init ""}
                        {id f_status type combobox label "Status:" width 180 \
                            options {Neu In Bearbeitung Wartend Erledigt} init Neu}
                    }}
                    {id f_bearbeiter type text label "Bearbeiter:"}
                    {id f_loesung type text label "Loesung / Massnahme:" \
                        multiline 1 fieldh 55}
                    {id f_geschlossen type text label "Geschlossen am:"}
                }]]]
}

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

set y [dict get $ctx top]
pdf4tclforms::renderSchema $pdf $ctx [schemaFehlermeldung] -yvar y -pagebreak 1

set outfile [file join $outdir demo_62_fehlermeldung.pdf]
$pdf endPage
$pdf write -file $outfile
$pdf destroy

puts "Fehlermeldung -> $outfile"
exit 0
