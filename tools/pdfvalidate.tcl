#!/usr/bin/env tclsh
# pdfvalidate.tcl -- PDF-Validator Stufe 1
#
# Prueft ein oder mehrere PDFs auf:
#   - Struktur (qpdf --check)
#   - Metadaten (pdfinfo)
#   - Fonts (pdffonts)
#   - Ueberlappungen, Rand, Linien durch Text (pdfanalyze.py / PyMuPDF)
#
# Usage:
#   tclsh pdfvalidate.tcl file.pdf [file2.pdf ...]
#   tclsh pdfvalidate.tcl examples/pdf/*.pdf
#   tclsh pdfvalidate.tcl -dir examples/pdf
#   tclsh pdfvalidate.tcl -h
#
# Exit-Code:
#   0 = alles OK
#   1 = mindestens ein FAIL
#   2 = mindestens ein WARN (aber kein FAIL)

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------
set CFG(warn_overlaps)    2    ;# ab wievielen Ueberlappungen WARN
set CFG(warn_lines)       1    ;# ab wievielen Linien durch Text WARN
set CFG(warn_margin)     -1    ;# Rand-Check deaktiviert (-1 = aus)
set CFG(warn_unembedded)  5    ;# ab wievielen nicht-eingebetteten Fonts WARN
set CFG(timeout)         15    ;# Sekunden pro Tool
set CFG(use_python)       1    ;# pdfanalyze.py nutzen (braucht PyMuPDF)
set CFG(verbose)          0    ;# ausfuehrliche Ausgabe
set CFG(color)            1    ;# ANSI-Farben

# pdfanalyze.py -- im gleichen Verzeichnis wie pdfvalidate.tcl
set CFG(pdfanalyze) [file join [file dirname [file normalize [info script]]] \
    pdfanalyze.py]

# ---------------------------------------------------------------------------
# ANSI-Farben
# ---------------------------------------------------------------------------
proc col {name} {
    global CFG
    if {!$CFG(color)} { return "" }
    switch $name {
        red     { return "\033\[31m" }
        green   { return "\033\[32m" }
        yellow  { return "\033\[33m" }
        blue    { return "\033\[34m" }
        bold    { return "\033\[1m"  }
        reset   { return "\033\[0m"  }
        default { return "" }
    }
}

proc cOK    {s} { return "[col green]$s[col reset]" }
proc cWARN  {s} { return "[col yellow]$s[col reset]" }
proc cFAIL  {s} { return "[col red]$s[col reset]" }
proc cINFO  {s} { return "[col blue]$s[col reset]" }
proc cBOLD  {s} { return "[col bold]$s[col reset]" }

# ---------------------------------------------------------------------------
# Tool-Verfuegbarkeit
# ---------------------------------------------------------------------------
proc toolAvail {name} {
    return [expr {![catch {exec which $name}]}]
}

set TOOLS(qpdf)     [toolAvail qpdf]
set TOOLS(pdfinfo)  [toolAvail pdfinfo]
set TOOLS(pdffonts) [toolAvail pdffonts]
set TOOLS(python3)  [toolAvail python3]

# ---------------------------------------------------------------------------
# Hilfs-Procs
# ---------------------------------------------------------------------------
proc runTool {args} {
    global CFG
    set rc [catch {exec {*}$args 2>@1} out]
    return [list $rc $out]
}

proc jsonGet {json key} {
    # Einfacher JSON-Extraktor fuer skalare Werte
    if {[regexp "\"$key\"\\s*:\\s*(-?\\d+)" $json -> val]} {
        return $val
    }
    return ""
}

# ---------------------------------------------------------------------------
# Validierungs-Procs
# ---------------------------------------------------------------------------

proc checkQpdf {pdf} {
    global TOOLS
    if {!$TOOLS(qpdf)} {
        return [list skip "qpdf nicht installiert"]
    }
    lassign [runTool qpdf --check $pdf] rc out
    if {$rc == 0} {
        return [list ok ""]
    } else {
        # qpdf gibt Warnungen als rc=3 zurück -- nur echte Fehler melden
        set lines [split $out \n]
        set errors [lsearch -all -inline -glob $lines "*ERROR*"]
        if {[llength $errors] > 0} {
            return [list fail [lindex $errors 0]]
        }
        return [list ok ""]
    }
}

proc checkPdfinfo {pdf} {
    global TOOLS
    if {!$TOOLS(pdfinfo)} {
        return [list skip "pdfinfo nicht installiert" {} {}]
    }
    lassign [runTool pdfinfo $pdf] rc out
    if {$rc != 0} {
        return [list fail $out {} {}]
    }
    # Seiten + Version extrahieren
    set pages ""
    set version ""
    set encrypted "no"
    foreach line [split $out \n] {
        if {[regexp {^Pages:\s+(\d+)} $line -> p]} { set pages $p }
        if {[regexp {^PDF version:\s+(\S+)} $line -> v]} { set version $v }
        if {[regexp {^Encrypted:\s+(\S+)} $line -> e]} { set encrypted $e }
    }
    set info "PDF $version, $pages Seite(n)"
    if {$encrypted ne "no"} { append info ", verschluesselt" }
    return [list ok $info $pages $version]
}

proc checkPdffonts {pdf} {
    global TOOLS CFG
    if {!$TOOLS(pdffonts)} {
        return [list skip "pdffonts nicht installiert" 0]
    }
    lassign [runTool pdffonts $pdf] rc out
    if {$rc != 0} {
        return [list fail $out 0]
    }
    # Nicht-eingebettete Fonts zählen
    set unembedded 0
    set lines [split $out \n]
    foreach line $lines {
        # Spalte "emb" ist "no" wenn nicht eingebettet
        if {[regexp {\s+no\s+} $line]} {
            incr unembedded
        }
    }
    if {$unembedded >= $CFG(warn_unembedded)} {
        return [list warn "$unembedded Font(s) nicht eingebettet" $unembedded]
    }
    return [list ok "" $unembedded]
}

proc checkPdfanalyze {pdf} {
    global TOOLS CFG
    if {!$TOOLS(python3) || !$CFG(use_python)} {
        return [list skip "python3/PyMuPDF nicht verfuegbar" {} {} {}]
    }
    if {![file exists $CFG(pdfanalyze)]} {
        return [list skip "pdfanalyze.py nicht gefunden" {} {} {}]
    }

    set tmpjson [file tempfile]
    append tmpjson ".json"
    lassign [runTool python3 $CFG(pdfanalyze) $pdf $tmpjson] rc out

    if {$rc != 0} {
        catch {file delete $tmpjson}
        return [list skip "PyMuPDF-Fehler: $out" {} {} {}]
    }

    # JSON lesen und Werte extrahieren
    set json ""
    if {[file exists $tmpjson]} {
        set fh [open $tmpjson r]
        set json [read $fh]
        close $fh
        file delete $tmpjson
    }

    # Werte aus erstem page-Eintrag
    set overlaps  [jsonGet $json "overlaps"]
    set linehits  [jsonGet $json "line_hits"]
    set margin    [jsonGet $json "margin_violations"]

    if {$overlaps eq ""} { set overlaps 0 }
    if {$linehits eq ""} { set linehits 0 }
    if {$margin   eq ""} { set margin   0 }

    set problems {}
    set status ok
    if {$overlaps >= $CFG(warn_overlaps)} {
        lappend problems "${overlaps} Ueberlappung(en)"
        set status warn
    }
    if {$linehits >= $CFG(warn_lines)} {
        lappend problems "${linehits} Linie(n) durch Text"
        set status warn
    }
    if {$CFG(warn_margin) >= 0 && $margin > $CFG(warn_margin)} {
        lappend problems "${margin} Rand-Verletzung(en)"
        set status warn
    } elseif {$margin > 0 && $CFG(verbose)} {
        lappend problems "${margin} Rand-Verletzung(en) (Info)"
    }

    set msg [join $problems ", "]
    return [list $status $msg $overlaps $linehits $margin]
}

# ---------------------------------------------------------------------------
# Ein PDF validieren
# ---------------------------------------------------------------------------
proc validateOne {pdf} {
    global CFG

    set name [file tail $pdf]
    set result ok
    set details {}

    # --- qpdf ---
    lassign [checkQpdf $pdf] qrc qmsg
    if {$qrc eq "fail"} { set result fail }

    # --- pdfinfo ---
    lassign [checkPdfinfo $pdf] irc imsg pages version
    if {$irc eq "fail"} { set result fail }

    # --- pdffonts ---
    lassign [checkPdffonts $pdf] frc fmsg unembedded
    if {$frc eq "warn" && $result eq "ok"} { set result warn }
    if {$frc eq "fail"} { set result fail }

    # --- pdfanalyze ---
    lassign [checkPdfanalyze $pdf] arc amsg overlaps linehits margin
    if {$arc eq "warn" && $result eq "ok"} { set result warn }
    if {$arc eq "fail"} { set result fail }

    # --- Ausgabe ---
    set size [file size $pdf]
    set sizeK [format "%.0f" [expr {$size / 1024.0}]]

    switch $result {
        ok   { set tag [cOK   "OK  "] }
        warn { set tag [cWARN "WARN"] }
        fail { set tag [cFAIL "FAIL"] }
    }

    # Hauptzeile
    set info ""
    if {$imsg ne ""} { append info "  $imsg" }
    if {$sizeK > 0}  { append info "  ${sizeK}KB" }
    puts "$tag  [cBOLD $name]$info"

    # Detail-Zeilen
    if {$qrc eq "fail"} {
        puts "      [cFAIL qpdf]:     $qmsg"
    }
    if {$irc eq "fail"} {
        puts "      [cFAIL pdfinfo]:  $imsg"
    }
    if {$frc eq "warn" || $frc eq "fail"} {
        puts "      [cWARN fonts]:    $fmsg"
    }
    if {$arc eq "warn"} {
        puts "      [cWARN analyze]:  $amsg"
    }
    if {$arc eq "skip" && $CFG(verbose)} {
        puts "      [cINFO analyze]:  $amsg"
    }

    if {$CFG(verbose)} {
        if {$qrc eq "ok"}   { puts "      [cINFO qpdf]:     OK" }
        if {$irc eq "ok"}   { puts "      [cINFO pdfinfo]:  $imsg" }
        if {$frc eq "ok"}   { puts "      [cINFO fonts]:    alle eingebettet" }
        if {$arc eq "ok"}   { puts "      [cINFO analyze]:  $amsg" }
    }

    return $result
}

# ---------------------------------------------------------------------------
# Argument-Parsing
# ---------------------------------------------------------------------------
proc usage {} {
    puts "Usage: tclsh pdfvalidate.tcl \[options\] file.pdf \[file2.pdf ...\]"
    puts ""
    puts "Options:"
    puts "  -dir <verzeichnis>   Alle *.pdf in Verzeichnis pruefen"
    puts "  -v                   Ausfuehrliche Ausgabe"
    puts "  -nocolor             Keine ANSI-Farben"
    puts "  -nopython            pdfanalyze.py nicht nutzen"
    puts "  -h                   Diese Hilfe"
    puts ""
    puts "Exit-Code: 0=OK  1=FAIL  2=WARN"
    exit 0
}

# Args parsen
set pdfs {}
set i 0
while {$i < $argc} {
    set arg [lindex $argv $i]
    switch -- $arg {
        -h      { usage }
        -v      { set CFG(verbose) 1 }
        -nocolor { set CFG(color) 0 }
        -nopython { set CFG(use_python) 0 }
        -dir {
            incr i
            set dir [lindex $argv $i]
            foreach f [lsort [glob -nocomplain [file join $dir *.pdf]]] {
                lappend pdfs $f
            }
        }
        default {
            if {[file exists $arg]} {
                lappend pdfs $arg
            } else {
                # Glob-Pattern?
                set found [glob -nocomplain $arg]
                if {[llength $found] > 0} {
                    lappend pdfs {*}$found
                } else {
                    puts stderr "Warnung: $arg nicht gefunden"
                }
            }
        }
    }
    incr i
}

if {[llength $pdfs] == 0} {
    puts stderr "Fehler: Keine PDF-Dateien angegeben."
    usage
}

# ---------------------------------------------------------------------------
# Hauptlauf
# ---------------------------------------------------------------------------
puts "[cBOLD "=== pdf4tcl Validator ==="]"
puts "Tools: qpdf=[expr {$TOOLS(qpdf)?{OK}:{MISS}}]  \
pdfinfo=[expr {$TOOLS(pdfinfo)?{OK}:{MISS}}]  \
pdffonts=[expr {$TOOLS(pdffonts)?{OK}:{MISS}}]  \
python3=[expr {$TOOLS(python3)?{OK}:{MISS}}]"
puts ""

set nOK 0; set nWARN 0; set nFAIL 0; set nTotal 0
set t0 [clock milliseconds]

foreach pdf $pdfs {
    incr nTotal
    set r [validateOne $pdf]
    switch $r {
        ok   { incr nOK }
        warn { incr nWARN }
        fail { incr nFAIL }
    }
}

set ms [expr {[clock milliseconds] - $t0}]
puts ""
puts "[string repeat - 60]"
puts "Ergebnis: [cOK "${nOK} OK"]  [cWARN "${nWARN} WARN"]  [cFAIL "${nFAIL} FAIL"]  \
von $nTotal PDFs  (${ms}ms)"

# Exit-Code
if {$nFAIL > 0} { exit 1 }
if {$nWARN > 0} { exit 2 }
exit 0
