#!/usr/bin/env tclsh
# run_all.tcl -- Startet alle Unit-Tests fuer pdf4tcllib
#
# Aufruf:
#   tclsh run_all.tcl
#   tclsh run_all.tcl -verbose p     ;# nur Pass/Fail
#   tclsh run_all.tcl -verbose bps   ;# Body, Pass, Skip

package require Tcl 8.6-

set testDir [file dirname [file normalize [info script]]]
set libDir [file normalize [file join $testDir .. lib]]

# pdf4tcllib laden
tcl::tm::path add $libDir
if {[catch {package require pdf4tcllib 0.1} err]} {
    puts stderr "FEHLER: pdf4tcllib konnte nicht geladen werden."
    puts stderr "  $err"
    puts stderr ""
    puts stderr "pdf4tcl muss installiert sein."
    exit 1
}

puts "pdf4tcllib [pdf4tcllib::version] geladen"
puts "Fonts: [pdf4tcllib::fonts::fontSans] (TTF: [pdf4tcllib::fonts::hasTtf])"
puts [string repeat "=" 60]

# Alle test_*.tcl Dateien ausfuehren
set files [lsort [glob -directory $testDir test_*.tcl]]
set total 0
set failed 0

foreach f $files {
    set name [file tail $f]
    puts "\n--- $name ---"
    set rc [catch {source $f} result]
    if {$rc} {
        puts "  FEHLER: $result"
        incr failed
    }
    incr total
}

puts "\n[string repeat "=" 60]"
puts "Test-Dateien: $total"
if {$failed > 0} {
    puts "FEHLGESCHLAGEN: $failed"
    exit 1
} else {
    puts "Alle bestanden."
}
