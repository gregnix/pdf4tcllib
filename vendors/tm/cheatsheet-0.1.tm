# cheatsheet-0.1.tm -- Cheat Sheet Generator fuer pdf4tcl
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
# Erzeugt professionelle 2-spaltige Cheat-Sheet PDFs aus reinen Daten.
# Trennung von Inhalt (Dict) und Layout (dieses Modul).
#
# Abhaengigkeit: pdf4tcl 0.9.4.23+
# Aufruf:
#   package require cheatsheet 0.1
#   cheatsheet::fromDict "output.pdf" $mydata
#
# Datenformat:
#   set data {
#       title    "Titel"
#       subtitle "Untertitel"
#       sections {
#           {title "Setup" type code content {
#               {lappend auto_path /pfad/}
#               {package require pdf4tcl}
#           }}
#           {title "Optionen" type table content {
#               {label1  "Beschreibung 1"}
#               {{Label mit Leerzeichen}  "Beschreibung"  0}
#           }}
#   Tabellenzeile: {label value ?mono?}; mehrteilige Labels in {{…}} klammern
#   (siehe docs/csd-format.md), sonst falsche Feldzuordnung / Fehler bei mono.
#           {title "Hinweis" type hint content {
#               "Wichtiger Hinweis"
#           }}
#       }
#   }
#
# Section-Typen:
#   table  -- 2-spaltig: label (bold) + value (Helvetica oder Courier)
#   code   -- Eintraege als Courier-Zeilen
#   hint   -- grauer Hintergrund, Hinweis-Text
#   list   -- eingerueckte Liste

package provide cheatsheet 0.1
package require pdf4tcl

namespace eval cheatsheet {

    # Layout-Konstanten
    variable C
    array set C {
        col1_x    8
        col2_x    302
        col_w     284
        val_off   85
        y_start   50
        y_max     650
        row_h     12
        code_h    10
        sec_h     20
        sep_h     8
        page_w    595
        page_h    842
        div_x     297
    }

    # Farben
    variable COL
    array set COL {
        header_r   0.1   header_g  0.2   header_b  0.5
        sec_r      0.88  sec_g     0.92  sec_b     0.98
        sec_txt_r  0.1   sec_txt_g 0.2   sec_txt_b 0.5
        hint_r     0.95  hint_g    0.95  hint_b    0.88
        lbl_r      0.35  lbl_g     0.35  lbl_b     0.35
        sep_r      0.80  sep_g     0.80  sep_b     0.80
        div_r      0.75  div_g     0.75  div_b     0.75
    }
}

# ---------------------------------------------------------------------------
# Interne Hilfsprocs
# ---------------------------------------------------------------------------

proc cheatsheet::_header {pdf title subtitle} {
    variable C
    variable COL
    $pdf setFillColor $COL(header_r) $COL(header_g) $COL(header_b)
    $pdf rectangle 0 0 $C(page_w) 40 -filled 1
    $pdf setFillColor 1 1 1
    $pdf setFont 14 Helvetica-Bold
    $pdf text $title -x 12 -y 10
    $pdf setFont 9 Helvetica
    $pdf text $subtitle -x 12 -y 26
    $pdf setFillColor 0 0 0
}

proc cheatsheet::_divider {pdf} {
    variable C
    variable COL
    $pdf setStrokeColor $COL(div_r) $COL(div_g) $COL(div_b)
    $pdf line $C(div_x) 45 $C(div_x) 820
    $pdf setStrokeColor 0 0 0
}

proc cheatsheet::_section {pdf title y col} {
    variable C
    variable COL
    set y [expr {$y + 4}]
    $pdf setFillColor $COL(sec_r) $COL(sec_g) $COL(sec_b)
    $pdf rectangle $col $y $C(col_w) 15 -filled 1
    $pdf setFillColor $COL(sec_txt_r) $COL(sec_txt_g) $COL(sec_txt_b)
    $pdf setFont 9 Helvetica-Bold
    $pdf text $title -x [expr {$col+4}] -y [expr {$y+10}]
    $pdf setFillColor 0 0 0
    return [expr {$y + $C(sec_h)}]
}

proc cheatsheet::_row {pdf label value y col {mono 0}} {
    variable C
    variable COL
    $pdf setFillColor $COL(lbl_r) $COL(lbl_g) $COL(lbl_b)
    $pdf setFont 8 Helvetica-Bold
    $pdf text $label -x [expr {$col+4}] -y [expr {$y+8}]
    if {$mono} {
        $pdf setFont 8 Courier
    } else {
        $pdf setFont 8 Helvetica
    }
    $pdf setFillColor 0 0 0
    set nlines 0
    set vx [expr {$col + $C(val_off)}]
    set vw [expr {$C(col_w) - $C(val_off) - 4}]
    $pdf drawTextBox $vx [expr {$y+1}] $vw 200 $value \
        -align left -linesvar nlines
    set h [expr {max($C(row_h), $nlines * 10 + 3)}]
    return [expr {$y + $h}]
}

proc cheatsheet::_code {pdf line y col} {
    variable C
    set vx [expr {$col+4}]
    set vw [expr {$C(col_w) - 8}]
    set nlines 0
    $pdf setFont 7 Courier
    $pdf setFillColor 0.15 0.15 0.15
    $pdf drawTextBox $vx [expr {$y+1}] $vw 200 $line -align left -linesvar nlines
    $pdf setFillColor 0 0 0
    if {$nlines < 1} { set nlines 1 }
    set h [expr {max($C(code_h), $nlines * 10 + 2)}]
    return [expr {$y + $h}]
}

proc cheatsheet::_hint {pdf text y col} {
    variable C
    variable COL
    set y [expr {$y + 2}]
    set vx [expr {$col+4}]
    set vw [expr {$C(col_w) - 8}]
    set nlines 0
    $pdf setFont 8 Helvetica
    $pdf drawTextBox $vx [expr {$y+1}] $vw 500 $text -align left -linesvar nlines -dryrun 1
    if {$nlines < 1} { set nlines 1 }
    set boxh [expr {max(14, $nlines * 10 + 8)}]
    $pdf setFillColor $COL(hint_r) $COL(hint_g) $COL(hint_b)
    $pdf rectangle $col $y $C(col_w) $boxh -filled 1
    $pdf setFillColor 0.4 0.2 0.0
    $pdf drawTextBox $vx [expr {$y+1}] $vw 500 $text -align left -linesvar nlines
    $pdf setFillColor 0 0 0
    return [expr {$y + $boxh + 4}]
}

proc cheatsheet::_sep {pdf y col} {
    variable C
    variable COL
    incr y 2
    $pdf setStrokeColor $COL(sep_r) $COL(sep_g) $COL(sep_b)
    $pdf line $col $y [expr {$col+$C(col_w)}] $y
    $pdf setStrokeColor 0 0 0
    return [expr {$y + 5}]
}

# Spalten-/Seitenwechsel
proc cheatsheet::_col {pdf y colVar title subtitle} {
    variable C
    upvar 1 $colVar col
    if {$y > $C(y_max)} {
        if {$col == $C(col1_x)} {
            set col $C(col2_x)
            return $C(y_start)
        } else {
            $pdf endPage
            $pdf startPage
            _header $pdf $title $subtitle
            _divider $pdf
            set col $C(col1_x)
            return $C(y_start)
        }
    }
    return $y
}

# Hoehe einer Section schaetzen (fuer Platzprueung)
proc cheatsheet::_sectionHeight {section} {
    variable C
    set type  [dict get $section type]
    set rows  [dict get $section content]
    set h $C(sec_h)
    switch $type {
        table {
            foreach row $rows {
                set value [lindex $row 1]
                set est [expr {max(1, int(ceil([string length $value] / 42.0)))}]
                incr h [expr {max($C(row_h), $est * 10 + 3)}]
            }
        }
        code {
            foreach line $rows {
                set est [expr {max(1, int(ceil([string length $line] / 48.0)))}]
                incr h [expr {max($C(code_h), $est * 10 + 2)}]
            }
        }
        hint {
            foreach line $rows {
                set est [expr {max(1, int(ceil([string length $line] / 35.0)))}]
                incr h [expr {$est * 10 + 10}]
            }
        }
        list {
            foreach item $rows {
                set est [expr {max(1, int(ceil(([string length $item] + 2) / 40.0)))}]
                incr h [expr {max($C(row_h), $est * 10)}]
            }
        }
    }
    return [expr {$h + $C(sep_h)}]
}

# ---------------------------------------------------------------------------
# Hauptproc: Section rendern
# ---------------------------------------------------------------------------
proc cheatsheet::_renderSection {pdf section y col} {
    variable C
    set title   [dict get $section title]
    set type    [dict get $section type]
    set content [dict get $section content]
    set mono    0
    if {[dict exists $section mono]} { set mono [dict get $section mono] }

    set y [_section $pdf $title $y $col]

    switch $type {
        table {
            foreach row $content {
                set label [lindex $row 0]
                set value [lindex $row 1]
                set m $mono
                if {[llength $row] >= 3} { set m [lindex $row 2] }
                set y [_row $pdf $label $value $y $col $m]
            }
        }
        code {
            foreach line $content {
                set y [_code $pdf $line $y $col]
            }
        }
        hint {
            foreach line $content {
                set y [_hint $pdf $line $y $col]
            }
        }
        list {
            $pdf setFont 8 Helvetica
            $pdf setFillColor 0 0 0
            set vx [expr {$col+8}]
            set vw [expr {$C(col_w) - 12}]
            foreach item $content {
                set nlines 0
                $pdf drawTextBox $vx [expr {$y+1}] $vw 200 "- $item" -align left -linesvar nlines
                if {$nlines < 1} { set nlines 1 }
                set h [expr {max($C(row_h), $nlines * 10 + 1)}]
                set y [expr {$y + $h}]
            }
        }
    }

    set y [_sep $pdf $y $col]
    return $y
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# render: Zeichnet alle Sections in pdf
# Gibt finales y zurueck
proc cheatsheet::render {pdf data} {
    variable C

    set title    [dict get $data title]
    set subtitle [dict get $data subtitle]
    set sections [dict get $data sections]

    $pdf startPage
    _header $pdf $title $subtitle
    _divider $pdf

    set y   $C(y_start)
    set col $C(col1_x)

    foreach section $sections {
        set need [_sectionHeight $section]
        for {set i 0} {$i < 24 && $y + $need > $C(y_max)} {incr i} {
            set y [_col $pdf [expr {$C(y_max)+1}] col $title $subtitle]
        }
        set y [_col $pdf $y col $title $subtitle]
        set y [_renderSection $pdf $section $y $col]
    }

    $pdf endPage
}

# fromDict: Erzeugt PDF-Datei aus Daten-Dict
proc cheatsheet::fromDict {outfile data} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    render $pdf $data
    $pdf write -file $outfile
    $pdf destroy
}

# fromDicts: Mehrere Sheets in eine PDF (mehrere Seiten)
proc cheatsheet::fromDicts {outfile datalist} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    foreach data $datalist {
        render $pdf $data
    }
    $pdf write -file $outfile
    $pdf destroy
}

# getDefaultStyle: gibt aktuelles Layout als Dict zurueck
proc cheatsheet::getStyle {} {
    variable C
    variable COL
    set result {}
    foreach k [array names C]   { dict set result layout $k $C($k) }
    foreach k [array names COL] { dict set result colors $k $COL($k) }
    return $result
}

# setStyle: ueberschreibt einzelne Layout-Werte
proc cheatsheet::setStyle {args} {
    variable C
    variable COL
    foreach {key val} $args {
        if {[info exists C($key)]}   { set C($key) $val; continue }
        if {[info exists COL($key)]} { set COL($key) $val; continue }
        error "Unbekannter Style-Key: $key"
    }
}
