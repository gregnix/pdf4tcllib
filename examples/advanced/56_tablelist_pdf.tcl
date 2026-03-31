#!/usr/bin/env wish
# ===========================================================================
# Demo 56: Tablelist -> PDF Export
#
# Zeigt alle Features von pdf4tcllib::tablelist::render:
#   - Einfache Tabelle (Kundenliste)
#   - Zellenfarben und Zeilenfarben aus Widget
#   - Zebra-Streifen aus Widget (-stripebackground)
#   - Spaltenausrichtung (left/right/center)
#   - Bold/Italic per Zeilenfont (-font)
#   - Tree-Modus mit Einrueckung
#   - -formatcommand (Zahlenformatierung)
#   - Mehrseitige Tabelle mit Seitenumbruch
#
# Voraussetzung: package tablelist_tile (Csaba Nemethi)
# ===========================================================================

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
#package require pdf4tcllib 0.2
package require pdf4tcltable 0.1
package require pdf4tcl

# tablelist -- aus vendors/ oder systemweit
set found 0
foreach p [list \
    [file join ~ tablelist tablelist7.9] \
    /usr/share/tcltk/tablelist7.9 \
    /usr/lib/tcltk/tablelist7.9 \
    [file normalize [file join $scriptDir .. .. .. tablelist tablelist7.9]] \
    [file normalize [file join $scriptDir .. .. .. .. tablelist tablelist7.9]] \
] {
    if {[file isdir $p]} {
        lappend auto_path $p
        set found 1
        break
    }
}

if {[catch {package require tablelist_tile} err]} {
    tk_messageBox -type ok -icon warning \
        -message "tablelist_tile nicht gefunden:\n$err\n\nBitte Pfad anpassen." \
        -title "Demo 56"
    exit 1
}

# pdf4tcllib::tablelist ist in pdf4tcllib-0.1.tm integriert
# (kein separates source nötig)

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_56_tablelist_pdf.pdf"]

# ===========================================================================
# Hilfsproc: Preis formatieren
# ===========================================================================
proc formatPrice {val} {
    if {![string is double -strict $val]} { return $val }
    return [format "%.2f EUR" $val]
}

# tablelist -formatcommand übergibt nur den Zellwert (1 Argument)
proc formatPriceCmd {val} {
    return [formatPrice $val]
}

# ===========================================================================
# GUI aufbauen
# ===========================================================================
wm title . "Demo 56: Tablelist -> PDF"
wm geometry . "1000x700+30+30"

# Notebook fuer 3 Demo-Tabellen
ttk::notebook .nb
pack .nb -fill both -expand 1

# ---------------------------------------------------------------------------
# Tab 1: Kundenliste (einfach + Farben)
# ---------------------------------------------------------------------------
set f1 [ttk::frame .nb.f1]
.nb add $f1 -text "Kundenliste"

set tbl1 [tablelist::tablelist $f1.tbl \
    -columns {
        8  "Nr."      right
        20 "Name"     left
        15 "Stadt"    left
        10 "Kategorie" center
        12 "Umsatz"   right
        10 "Status"   center
    } \
    -stripebackground "#f0f4ff" \
    -stripeforeground black \
    -font {Helvetica 9} \
    -selectmode extended \
    -height 12 \
    -stretch all \
    -labelcommand tablelist::sortByColumn]

# Formatierungsbefehl fuer Umsatz-Spalte
$tbl1 columnconfigure 4 -formatcommand formatPriceCmd
$tbl1 columnconfigure 4 -sortmode real

pack $tbl1 -fill both -expand 1 -padx 4 -pady 4

# Daten einfuegen
set kunden {
    {1001 "Müller GmbH"       "Berlin"    "Premium"  125000.50 "Aktiv"}
    {1002 "Schmidt & Co"      "Hamburg"   "Standard"  48500.00 "Aktiv"}
    {1003 "Weber Handel"      "München"   "Premium"   92300.75 "Aktiv"}
    {1004 "Fischer KG"        "Frankfurt" "Basic"      8900.00 "Inaktiv"}
    {1005 "Becker Solutions"  "Köln"      "Standard"  35600.25 "Aktiv"}
    {1006 "Wagner Systems"    "Stuttgart" "Premium"  210450.00 "Aktiv"}
    {1007 "Hoffmann Import"   "Leipzig"   "Basic"     15200.50 "Aktiv"}
    {1008 "Klein Logistik"    "Dresden"   "Standard"  62800.00 "Inaktiv"}
    {1009 "Richter Tech"      "Hannover"  "Premium"  178900.25 "Aktiv"}
    {1010 "Wolf Consulting"   "Bremen"    "Basic"      5400.00 "Aktiv"}
    {1011 "Schneider Bau"     "Dortmund"  "Standard"  41200.75 "Aktiv"}
    {1012 "Zimmermann GmbH"   "Essen"     "Premium"   98700.00 "Inaktiv"}
}

# Erst alle Zeilen einfuegen
foreach row $kunden {
    $tbl1 insert end $row
}

# WICHTIG: tablelist muss gerendert sein bevor cellconfigure aufgerufen wird
update idletasks

# Dann Farben/Fonts setzen
for {set r 0} {$r < [$tbl1 size]} {incr r} {
    set row [$tbl1 get $r]
    if {[lindex $row 5] eq "Inaktiv"} {
        $tbl1 rowconfigure $r -background "#ffe0e0" -foreground "#cc0000"
    }
    if {[lindex $row 3] eq "Premium"} {
        $tbl1 cellconfigure $r,3 -foreground "#003399" \
            -font {Helvetica 9 bold}
    }
    if {[lindex $row 4] > 100000} {
        $tbl1 cellconfigure $r,4 -foreground "#006600" \
            -font {Helvetica 9 bold}
    }
}

# ---------------------------------------------------------------------------
# Tab 2: Produktkatalog (Tree-Modus)
# ---------------------------------------------------------------------------
set f2 [ttk::frame .nb.f2]
.nb add $f2 -text "Produktbaum"

set tbl2 [tablelist::tablelist $f2.tbl \
    -columns {
        25 "Produkt/Kategorie" left
        10 "Art.-Nr."          center
        8  "Einheit"           center
        10 "Preis"             right
        8  "Lager"             right
    } \
    -treecolumn 0 \
    -stripebackground "#f5f5f5" \
    -font {Helvetica 9} \
    -height 14 \
    -stretch all]

$tbl2 columnconfigure 3 -formatcommand formatPriceCmd

pack $tbl2 -fill both -expand 1 -padx 4 -pady 4

# Baum aufbauen: Kategorien und Produkte
proc addCategory {tbl parent name} {
    set r [$tbl insertchild $parent end \
        [list $name "" "" "" ""]]
    $tbl rowconfigure $r -font {Helvetica 9 bold} \
        -background "#dde8f8"
    return $r
}

proc addProduct {tbl parent artNr name einheit preis lager} {
    set r [$tbl insertchild $parent end \
        [list $name $artNr $einheit $preis $lager]]
    return $r
}

set root end
set cat1 [addCategory $tbl2 root "Elektronik"]
    addProduct $tbl2 $cat1 "E-001" "Laptop 15"    Stk  899.99  42
    addProduct $tbl2 $cat1 "E-002" "Laptop 13"    Stk  749.00  18
    addProduct $tbl2 $cat1 "E-003" "Maus kabellos" Stk   24.99 150
    addProduct $tbl2 $cat1 "E-004" "Tastatur DE"   Stk   39.95  87

set cat2 [addCategory $tbl2 root "Bürobedarf"]
    addProduct $tbl2 $cat2 "B-001" "Drucker A4"    Stk  189.00  12
    addProduct $tbl2 $cat2 "B-002" "Papier A4 500" Pak    4.99 320
    addProduct $tbl2 $cat2 "B-003" "Ordner A4"     Stk    2.49 890
    addProduct $tbl2 $cat2 "B-004" "Toner schwarz" Stk   42.00  35

set cat3 [addCategory $tbl2 root "Software"]
    addProduct $tbl2 $cat3 "S-001" "Office Lizenz"  Stk  299.00  99
    addProduct $tbl2 $cat3 "S-002" "Antivirus 1 J." Stk   29.99 999
    addProduct $tbl2 $cat3 "S-003" "VPN Jahresabo"  Stk   59.00 999

$tbl2 expandall

# ---------------------------------------------------------------------------
# Tab 3: Zeitreihe (viele Zeilen, Seitenumbruch)
# ---------------------------------------------------------------------------
set f3 [ttk::frame .nb.f3]
.nb add $f3 -text "Monatsdaten"

set tbl3 [tablelist::tablelist $f3.tbl \
    -columns {
        10 "Monat"    left
        10 "Einnahmen" right
        10 "Ausgaben"  right
        10 "Saldo"     right
        8  "Trend"     center
    } \
    -stripebackground "#f0fff0" \
    -font {Helvetica 9} \
    -height 12 \
    -stretch all]

foreach c {1 2 3} {
    $tbl3 columnconfigure $c -formatcommand formatPriceCmd
    $tbl3 columnconfigure $c -sortmode real
}

pack $tbl3 -fill both -expand 1 -padx 4 -pady 4

# 36 Monate generieren
set monate {Jan Feb Mär Apr Mai Jun Jul Aug Sep Okt Nov Dez}
set srand 42
set monatsDaten {}
for {set yr 2023} {$yr <= 2025} {incr yr} {
    foreach mon $monate {
        set srand [expr {($srand * 1103515245 + 12345) & 0x7fffffff}]
        set ein [expr {15000 + ($srand % 8000)}]
        set srand [expr {($srand * 1103515245 + 12345) & 0x7fffffff}]
        set aus [expr {12000 + ($srand % 5000)}]
        set sal [expr {$ein - $aus}]
        set trend [expr {$sal > 3000 ? "↑" : ($sal < 1000 ? "↓" : "→")}]
        $tbl3 insert end [list "$mon $yr" $ein $aus $sal $trend]
        lappend monatsDaten $sal
    }
}

update idletasks

for {set r 0} {$r < [$tbl3 size]} {incr r} {
    set sal [lindex $monatsDaten $r]
    if {$sal < 1000} {
        $tbl3 rowconfigure $r -foreground "#aa0000"
        $tbl3 cellconfigure $r,4 -font {Helvetica 9 bold}
    } elseif {$sal > 3000} {
        $tbl3 cellconfigure $r,3 -foreground "#006600" \
            -font {Helvetica 9 bold}
    }
}

# ===========================================================================
# Export-Button
# ===========================================================================
frame .btns -pady 8
pack .btns
button .btns.exp -text "PDF exportieren" -command exportPDF \
    -font {Helvetica 10 bold} -bg "#0055aa" -fg white \
    -relief raised -padx 12 -pady 4
button .btns.q -text "Schliessen" -command exit -padx 8
pack .btns.exp .btns.q -side left -padx 6

label .status -text "" -fg "#006600" -font {Helvetica 9}
pack .status

# ===========================================================================
# PDF Export
# ===========================================================================
proc exportPDF {} {
    global outPDF tbl1 tbl2 tbl3

    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]

    set lx [dict get $ctx left]
    set tw [dict get $ctx text_w]
    set top [dict get $ctx top]

    # -----------------------------------------------------------------------
    # Seite 1: Kundenliste
    # -----------------------------------------------------------------------
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 56: Tablelist -> PDF Export"
    pdf4tcllib::page::footer $pdf $ctx "Seite 1" 1

    set y [expr {$top + 14}]

    $pdf setFont 13 Helvetica-Bold
    $pdf text "1. Kundenliste" -x $lx -y $y
    set y [expr {$y + 18}]

    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.3 0.3 0.3
    $pdf text "Zellenfarben, Zeilenfarben und Zebra-Streifen aus dem Widget" \
        -x $lx -y $y
    $pdf setFillColor 0 0 0
    set y [expr {$y + 14}]

    # Kundenliste exportieren
    pdf4tcllib::tablelist::render $pdf $tbl1 $lx $y \
        -maxwidth $tw \
        -fontsize 8.5 \
        -border 1 \
        -zebra 1 \
        -ctx $ctx \
        -yvar y

    $pdf endPage

    # -----------------------------------------------------------------------
    # Seite 2: Produktbaum (Tree-Modus)
    # -----------------------------------------------------------------------
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 56: Tablelist -> PDF Export"
    pdf4tcllib::page::footer $pdf $ctx "Seite 2" 2

    set y [expr {$top + 14}]

    $pdf setFont 13 Helvetica-Bold
    $pdf text "2. Produktkatalog (Tree-Modus)" -x $lx -y $y
    set y [expr {$y + 18}]

    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.3 0.3 0.3
    $pdf text "Hierarchische Darstellung mit Einrueckung nach Baumtiefe" \
        -x $lx -y $y
    $pdf setFillColor 0 0 0
    set y [expr {$y + 14}]

    pdf4tcllib::tablelist::render $pdf $tbl2 $lx $y \
        -maxwidth $tw \
        -fontsize 8.5 \
        -border 1 \
        -zebra 1 \
        -tree 1 \
        -indentW 14 \
        -ctx $ctx \
        -yvar y

    $pdf endPage

    # -----------------------------------------------------------------------
    # Seiten 3+: Monatsdaten (Seitenumbruch)
    # -----------------------------------------------------------------------
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 56: Tablelist -> PDF Export"

    set y [expr {$top + 14}]
    set pageNum 3

    $pdf setFont 13 Helvetica-Bold
    $pdf text "3. Monatsdaten 2023-2025 (Seitenumbruch)" -x $lx -y $y
    set y [expr {$y + 18}]

    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.3 0.3 0.3
    $pdf text "36 Zeilen -- automatischer Seitenumbruch" -x $lx -y $y
    $pdf setFillColor 0 0 0
    set y [expr {$y + 14}]

    # Monatsdaten mit Seitenumbruch
    set nrows [$tbl3 size]
    set rh    15  ;# Zeilenhoehe

    # Header-Hoehe reservieren
    set firstPageRows [expr {int(([dict get $ctx bottom] - $y - $rh) / $rh)}]

    # Block-weise exportieren
    set from 0
    set firstBlock 1
    while {$from < $nrows} {
        if {$firstBlock} {
            set maxRows $firstPageRows
        } else {
            set maxRows [expr {int(([dict get $ctx bottom] \
                - [dict get $ctx top] - 24 - $rh) / $rh)}]
        }
        set to [expr {min($from + $maxRows - 1, $nrows - 1)}]

        # Teilabschnitt exportieren via _renderRange
        pdf4tcllib::tablelist::renderRange $pdf $tbl3 $lx $y \
            -maxwidth $tw \
            -fontsize 8.5 \
            -border 1 \
            -zebra 1 \
            -firstrow $from \
            -lastrow  $to \
            -ctx $ctx \
            -yvar y

        set from [expr {$to + 1}]

        if {$from < $nrows} {
            pdf4tcllib::page::footer $pdf $ctx "Seite $pageNum" $pageNum
            $pdf endPage
            incr pageNum
            $pdf startPage
            pdf4tcllib::page::header $pdf $ctx \
                "Demo 56: Monatsdaten (Fortsetzung)"
            pdf4tcllib::page::footer $pdf $ctx "Seite $pageNum" $pageNum
            set y [expr {[dict get $ctx top] + 14}]
            set firstBlock 0
        }
    }

    pdf4tcllib::page::footer $pdf $ctx "Seite $pageNum" $pageNum
    $pdf endPage

    $pdf write -file $outPDF
    $pdf destroy

    .status configure -text "Geschrieben: [file tail $outPDF]"
    .btns.exp configure -bg "#006600" -state disabled \
        -text "Exportiert: [file tail $outPDF]"
    puts "PDF: $outPDF"
}

# ===========================================================================
# renderRange -- Export eines Zeilenbereichs (fuer Seitenumbruch)
# ===========================================================================
