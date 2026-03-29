#!/usr/bin/env tclsh
# Demo 38: PDF-Verschluesselung (pdf4tcl -userpw / -ownerpw)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir

# ---------------------------------------------------------------------------
# 1. Mit Benutzerpasswort -- PDF oeffnet nur mit Passwort
# ---------------------------------------------------------------------------
set outfile [file join $outdir "demo_38_encrypted.pdf"]

# Verschluesselung braucht Tcllib aes (package require aes)
# Ohne Tcllib: PDF wird unverschluesselt erzeugt mit Hinweis
set encOpts {}
if {![catch {package require aes}]} {
    set encOpts [list -userpassword "benutzer" -ownerpassword "eigentuemer"]
    puts "Verschluesselung: AES aktiv"
} else {
    puts "Hinweis: Tcllib 'aes' nicht verfuegbar -- PDF wird unverschluesselt erzeugt"
    puts "Installation: sudo apt install tcllib  oder  teacup install aes"
}
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1 {*}$encOpts]
$pdf startPage

$pdf setFont 16 Helvetica-Bold
$pdf text "Demo 38 -- PDF-Verschluesselung" -x 60 -y 40
$pdf setFont 10 Helvetica
$pdf text "Dieses PDF ist mit AES-128 verschluesselt." -x 60 -y 62

$pdf setFont 11 Helvetica-Bold
$pdf text "Zugangsdaten:" -x 60 -y 95
$pdf setFont 10 Helvetica
$pdf text "Benutzerpasswort:   benutzer" -x 80 -y 113
$pdf text "Eigentuemerpasswort: eigentuemer" -x 80 -y 130

# Infobox
$pdf setFillColor 0.93 0.97 1.0
$pdf setStrokeColor 0.6 0.8 1.0
$pdf setLineWidth 0.5
$pdf rectangle 55 150 460 80 -filled 1
$pdf setFont 10 Helvetica-Bold
$pdf setFillColor 0.1 0.3 0.6
$pdf text "pdf4tcl Optionen:" -x 65 -y 168
$pdf setFont 9 Helvetica
$pdf text {-userpassword "benutzer"   ;# Oeffnen nur mit Passwort} -x 65 -y 184
$pdf text {-ownerpassword "eigentuemer"  ;# Vollzugriff (Bearbeiten, Drucken)} -x 65 -y 200
$pdf text {-permissions {print copy}  ;# Benutzerrechte einschraenken} -x 65 -y 216
$pdf setFillColor 0 0 0
$pdf setStrokeColor 0 0 0

$pdf setFont 11 Helvetica-Bold
$pdf text "Hinweise:" -x 60 -y 252
$pdf setFont 10 Helvetica
set hints {
    "Nur Benutzerpasswort: Leser muss PW kennen"
    "Nur Eigentuemerpasswort: PDF oeffnet direkt, Bearbeiten gesperrt"
    "Beide Passwoerter: maximale Kontrolle"
    "PDF/A erlaubt keine Verschluesselung (Konflikt mit Standard)"
    "AES-256 verfuegbar mit Tcllib (langsamer, staerker)"
}
set y 270
foreach h $hints {
    $pdf text "- $h" -x 70 -y $y
    set y [expr {$y + 16}]
}

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Geschrieben: $outfile"
puts "(Passwort: benutzer)"
