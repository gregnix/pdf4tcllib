#!/usr/bin/env tclsh
# ===========================================================================
# Demo 43: Documents from a template (pdf4tcltemplate)
#
# Two templates, three documents:
#   demo_43_lieferschein.pdf   a delivery note over two pages, PDF/A-3b,
#                              "Seite n von m" in the footer
#   demo_43_brief.pdf          a letter: logo, address, body text in the
#                              flow, bank details in the footer
#   demo_43_lieferschein_b.pdf the same delivery-note template for another
#                              customer: one block hidden, one moved
#
# The template says where blocks sit; the data says what they show. The
# module computes nothing -- every number arrives as text.
# ===========================================================================

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib
package require pdf4tcltemplate

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set logo [file normalize [file join $scriptDir ../../tests/images testbild-100x83.png]]

# PDF/A needs embedded fonts; fonts::init finds a TrueType family.
::pdf4tcllib::fonts::init

# ---------------------------------------------------------------------------
# Template 1: delivery note
# ---------------------------------------------------------------------------
set lieferschein {
    paper a4  margin 20  size 10
    theme {accent {0.15 0.30 0.20} muted {0.40 0.40 0.40}}
    blocks {
        firma     {x 20 y 18 w 110 size 18 bold 1 color accent}
        logo      {type image x 160 y 12 w 30 h 25 align right}
        kontakt   {x 120 y 40 w 70 size 8 color muted align right list 1}
        absender  {x 20 y 45 w 85 size 7 color muted}
        anschrift {x 20 y 50 w 85 size 11 list 1}
        angaben   {type pairs x 125 y 55 w 65 labelw 32 size 9}
        titel     {x 20 y 95 w 170 size 15 bold 1 color accent
                   text "Lieferschein {nummer}"}
        einleitung {x 20 y 104 w 170}
        positionen {type table x 20 y 112 w 170 size 9 zebra 1
                    cols {{key pos title Pos w 12 align right}
                          {key artikel title Artikel w 24}
                          {key text title Bezeichnung}
                          {key menge title Menge w 20 align right}
                          {key einheit title Einheit w 16}}}
        hinweis   {x 20 y 0 w 170 gap 8 color muted}
        empfang   {x 20 y 0 w 80 gap 18 size 8 color muted
                   text "Ware erhalten (Datum, Unterschrift)"}
        linie     {type rule x 20 y 287 w 170 size 0.3 page all}
        fuss      {x 20 y 289 w 170 size 8 color muted page all align center
                   text "{firma} · Lieferschein {nummer} · Seite {page} von {pages}"}
    }
}

set rows {}
set n 0
foreach {art text menge} {
    ROS-ROT "Rose, rot (3 Tray à 300)"           900
    TUL-MIX "Tulpe, Mischung (2 Tray à 100)"     200
    NAR-GEL "Narzisse, gelb"                     45
} { lappend rows [dict create pos [incr n] artikel $art text $text menge $menge einheit Stk] }
for {set i 1} {$i <= 34} {incr i} {
    lappend rows [dict create pos [incr n] artikel TOP-[format %02d $i] \
        text "Tontopf, natur, [expr {8 + $i % 6 * 2}] cm" menge [expr {$i * 12}] einheit Stk]
}

set daten [dict create \
    firma     "Gärtnerei Beispiel" \
    logo      $logo \
    kontakt   {"Gartenweg 1" "12345 Grünfeld" "Tel. 01234 5678"} \
    absender  "Gärtnerei Beispiel · Gartenweg 1 · 12345 Grünfeld" \
    anschrift {"Blumenhaus Müller" "" "Hauptstraße 5" "54321 Stadt"} \
    angaben   {Nummer LS-2026-0007 Datum 08.11.2026 Kunde K12 Bestellung {}} \
    nummer    LS-2026-0007 \
    einleitung "Wir liefern Ihnen:" \
    positionen $rows \
    hinweis   "Bitte prüfen Sie die Ware bei Anlieferung.\nVielen Dank für Ihren Auftrag."]

proc schreibe {datei layout daten} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -pdfa 3b]
    set r [::pdf4tcllib::template::render $pdf $layout $daten]
    $pdf write -file $datei
    $pdf destroy
    puts "Written: $datei ([dict get $r pages] Seite(n))"
}

schreibe [file join $outdir demo_43_lieferschein.pdf] $lieferschein $daten

# ---------------------------------------------------------------------------
# Same template, another customer: hide the logo, move the address down.
# A program would store such a variant per customer or per printer.
# ---------------------------------------------------------------------------
set variante $lieferschein
dict set variante blocks logo show 0
dict set variante blocks anschrift y 55
dict set variante blocks absender y 50
set daten2 [dict replace $daten \
    anschrift {"Floristik Weber" "z. Hd. Frau Weber" "Am Markt 2" "65432 Dorf"} \
    angaben   {Nummer LS-2026-0008 Datum 08.11.2026 Kunde K31} \
    nummer    LS-2026-0008 \
    positionen [lrange $rows 0 4]]
schreibe [file join $outdir demo_43_lieferschein_b.pdf] $variante $daten2

# ---------------------------------------------------------------------------
# Template 2: letter. The body is a text block in the flow below the
# subject; a long body continues on the next page between lines.
# ---------------------------------------------------------------------------
set brief {
    paper a4  margin 20  size 11
    theme {accent {0.15 0.30 0.20} muted {0.40 0.40 0.40}}
    blocks {
        logo      {type image x 20 y 12 w 30 h 25}
        firma     {x 55 y 18 w 135 size 16 bold 1 color accent}
        absender  {x 20 y 45 w 85 size 7 color muted}
        anschrift {x 20 y 50 w 85 list 1}
        datum     {x 125 y 80 w 65 align right}
        betreff   {x 20 y 95 w 170 bold 1}
        text      {x 20 y 0 w 170 gap 8 leading 15}
        gruss     {x 20 y 0 w 170 gap 8}
        bank1     {x 20 y 280 w 55 size 7 color muted page all list 1}
        bank2     {x 77 y 280 w 55 size 7 color muted page all list 1}
        bank3     {x 135 y 280 w 55 size 7 color muted page all list 1 align right}
    }
}
set brieftext "Sehr geehrte Frau Müller,\n\nvielen Dank für Ihre Anfrage. Gern\
    liefern wir Ihnen die gewünschten Rosen ab der kommenden Woche, jeweils\
    dienstags und freitags.\n\nDie Preise gelten je 1000 Stück und schließen\
    die Trays ein. Leere Trays nehmen wir bei der nächsten Lieferung zurück.\n\n\
    Für Rückfragen sind wir werktags von 7 bis 16 Uhr erreichbar."
set briefdaten [dict create \
    logo      $logo \
    firma     "Gärtnerei Beispiel" \
    absender  "Gärtnerei Beispiel · Gartenweg 1 · 12345 Grünfeld" \
    anschrift {"Blumenhaus Müller" "Frau Anna Müller" "Hauptstraße 5" "54321 Stadt"} \
    datum     "Grünfeld, 8. November 2026" \
    betreff   "Ihre Anfrage vom 3. November" \
    text      $brieftext \
    gruss     "Mit freundlichen Grüßen\n\n\nPeter Beispiel" \
    bank1     {"Gärtnerei Beispiel" "Gartenweg 1, 12345 Grünfeld"} \
    bank2     {"Beispielbank" "IBAN DE00 0000 0000 0000 0000 00"} \
    bank3     {"USt-IdNr. DE000000000" "Amtsgericht Grünfeld HRA 0000"}]
schreibe [file join $outdir demo_43_brief.pdf] $brief $briefdaten
