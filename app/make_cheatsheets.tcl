#!/usr/bin/env tclsh
# make_cheatsheets -- Erzeugt Cheat-Sheet PDFs aus .csd Datendateien
#
# Verzeichnisstruktur:
#   app/
#     make_cheatsheets      <- dieses Skript
#     csdata/
#       pdf4tcl.csd
#       pdf.csd
#       canvas.csd
#       pdf-internals.csd
#   out/                    <- Ausgabe-PDFs
#
# Aufruf:
#   tclsh app/make_cheatsheets ?outdir?

set scriptDir [file dirname [file normalize [info script]]]

# cheatsheet-0.1.tm laden
foreach tmPath [list \
    [file normalize [file join $scriptDir ../../vendors/tm]] \
    [file normalize [file join $scriptDir ../vendors/tm]] \
    [file normalize [file join $scriptDir vendors/tm]] \
] {
    if {[file isdir $tmPath]} {
        tcl::tm::path add $tmPath
        break
    }
}

package require pdf4tcl
package require cheatsheet 0.1

# Ausgabeverzeichnis: Argument oder ./out
set outDir [expr {$argc > 0
    ? [lindex $argv 0]
    : [file normalize [file join $scriptDir ./out]]}]
file mkdir $outDir

# .csd-Datei lesen -- gibt den Dict-Inhalt als String zurueck
proc loadCsd {path} {
    set f [open $path]
    set data [read $f]
    close $f
    return [string trim $data]
}

# Alle .csd Dateien aus csdata/ einlesen (alphabetisch)
set csdDir [file join $scriptDir csdata]
set csdFiles [lsort [glob -nocomplain -dir $csdDir *.csd]]

if {[llength $csdFiles] == 0} {
    puts stderr "FEHLER: Keine .csd Dateien in $csdDir"
    exit 1
}

set ok 0
set err 0

foreach csdFile $csdFiles {
    # PDF-Name: foo.csd -> foo.pdf
    set base [file rootname [file tail $csdFile]]
    set outFile [file join $outDir ${base}.pdf]

    if {[catch {
        cheatsheet::fromDict $outFile [loadCsd $csdFile]
    } msg]} {
        puts stderr "FEHLER [file tail $csdFile]: $msg"
        incr err
    } else {
        puts "  [file tail $outFile]"
        incr ok
    }
}

puts "\n$ok PDF(s) in: $outDir"
if {$err > 0} { puts stderr "$err Fehler." }
