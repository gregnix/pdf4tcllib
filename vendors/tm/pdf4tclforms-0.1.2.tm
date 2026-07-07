# pdf4tclforms -- Deklarative PDF-AcroForm-Layouts
#
# Baut auf pdf4tcllib::form (addForm-Hilfen) auf und ergaenzt
# renderSchema / Vorlagen fuer ausfuellbare Formulare.
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License
#
#   package require pdf4tclforms
#   pdf4tclforms::renderSchema $pdf $ctx $spec -yvar y
#
# 0.1.2: field appearance (align/color/border*/bgcolor), live calculation
#        (calculate) and number formatting (format) pass-through; calculated
#        sum lines (sums: id/calculate/over/format). Needs pdf4tcl 0.9.4.33+
#        for the format feature (calculate: 0.9.4.32+, appearance: 0.9.4.30+).

package require Tcl 8.6-
package require pdf4tcllib 0.3
package require pdf4tcl 0.9.4.34

package provide pdf4tclforms 0.1.2

namespace eval ::pdf4tcllib::forms {
    # form:: exportiert seine Procs zwar, aber wir rufen sie hier bewusst
    # vollqualifiziert (::pdf4tcllib::form::...) auf -- kein namespace import,
    # damit form:: und forms:: (ein Buchstabe Unterschied) nicht kollidieren.
}

# ---------------------------------------------------------------- helpers

# Weiterleitung auf den Basis-Shim in pdf4tcllib (single-key dict getdef).
proc ::pdf4tcllib::forms::_getdef {d key default} {
    return [::pdf4tcllib::_dictGetdef $d $key $default]
}

proc ::pdf4tcllib::forms::_bool {v} {
    return [expr {!!$v}]
}

proc ::pdf4tcllib::forms::_ensureSpace {pdf ctx yVar needH {pagebreak 0}} {
    upvar 1 $yVar y
    if {!$pagebreak} { return }
    set bottom [dict get $ctx bottom]
    if {$y + $needH <= $bottom} { return }
    $pdf endPage
    $pdf startPage
    set y [dict get $ctx top]
}

proc ::pdf4tcllib::forms::_cfg {} {
    return [::pdf4tcllib::form::configure]
}

proc ::pdf4tcllib::forms::_drawTitle {pdf ctx yVar title} {
    upvar 1 $yVar y
    array set CFG [_cfg]
    set x [dict get $ctx SX]
    $pdf setFont 16 $CFG(fontFamilyBold)
    $pdf text $title -x $x -y [expr {$y + 14}]
    ::pdf4tcllib::page::_advance $ctx y 28
}

proc ::pdf4tcllib::forms::_labelWithRequired {pdf x y label required fieldH} {
    array set CFG [_cfg]
    $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamily)
    lassign $CFG(labelColor) lr lg lb
    $pdf setFillColor $lr $lg $lb
    set textY [expr {$y + $fieldH - 2}]
    $pdf text $label -x $x -y $textY
    if {$required} {
        $pdf setFont 10 Helvetica-Oblique
        $pdf setFillColor 0.8 0 0
        set lw [pdf4tcllib::text::width $label $CFG(fontSizeLabel) $CFG(fontFamily)]
        $pdf text "*" -x [expr {$x + $lw + 2}] -y $textY
        $pdf setFillColor 0 0 0
    }
}

proc ::pdf4tcllib::forms::_fieldAddArgs {fdef} {
    # Nur echte addForm-Optionen — Schema-Keys wie "label" nie durchreichen.
    # Appearance-Optionen (align/color/border*) brauchen pdf4tcl 0.9.4.30+,
    # calculate pdf4tcl 0.9.4.32+, format pdf4tcl 0.9.4.33+.
    set addArgs {}
    foreach key {id init options readonly multiline required tooltip tabindex \
                 align color borderwidth bordercolor bgcolor calculate format js} {
        if {![dict exists $fdef $key]} { continue }
        set val [dict get $fdef $key]
        if {$key eq "required"} {
            set val [_bool $val]
        } elseif {$key eq "init"} {
            set ftype [_getdef $fdef type text]
            if {$ftype in {checkbox checkbutton}} {
                set val [_bool $val]
            }
        }
        lappend addArgs -$key $val
    }
    return $addArgs
}

proc ::pdf4tcllib::forms::_addForm {pdf ftype x y w h fdef} {
    $pdf addForm $ftype $x $y $w $h {*}[::pdf4tcllib::forms::_fieldAddArgs $fdef]
}

# Checkbox mit Beschriftung rechts daneben (Telefonprotokoll-Stil).
proc ::pdf4tcllib::forms::checkboxLine {pdf ctx yVar fdef {pagebreak 0}} {
    upvar 1 $yVar y
    array set CFG [_cfg]

    set label    [_getdef $fdef label ""]
    set required [_bool [_getdef $fdef required 0]]
    set boxH 15
    ::pdf4tcllib::forms::_ensureSpace $pdf $ctx y [expr {$boxH + $CFG(rowGap)}] $pagebreak

    set x [dict get $ctx SX]
    ::pdf4tcllib::forms::_addForm $pdf checkbutton $x $y $boxH $boxH $fdef
    if {$label ne ""} {
        $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamily)
        $pdf text $label -x [expr {$x + $boxH + 6}] -y [expr {$y + $boxH - 2}]
        if {$required} {
            $pdf setFont 10 Helvetica-Oblique
            $pdf setFillColor 0.8 0 0
            set lw [pdf4tcllib::text::width $label $CFG(fontSizeLabel) $CFG(fontFamily)]
            $pdf text "*" -x [expr {$x + $boxH + 8 + $lw}] -y [expr {$y + $boxH - 2}]
            $pdf setFillColor 0 0 0
        }
    }
    ::pdf4tcllib::page::_advance $ctx y [expr {$boxH + $CFG(rowGap)}]
}

# Radio-Gruppe: label + mehrere radiobuttons (ein /Btn-Feld je -group).
# fdef: {type radio label ".." group NAME options {{value "Label"} ..} ?init default? ?required?}
proc ::pdf4tcllib::forms::radioGroup {pdf ctx yVar fdef {pagebreak 0}} {
    upvar 1 $yVar y
    array set CFG [_cfg]
    set label    [_getdef $fdef label ""]
    set group    [_getdef $fdef group [_getdef $fdef id ""]]
    set opts     [_getdef $fdef options {}]
    set default  [_getdef $fdef init ""]
    set required [_bool [_getdef $fdef required 0]]
    set boxH 14
    set x  [dict get $ctx SX]
    set sw [dict get $ctx SW]
    set labelW  [_getdef $fdef labelw $CFG(labelW)]
    set startBx [expr {$x + ($label ne "" ? $labelW + $CFG(labelGap) : 0)}]
    set maxX    [expr {$x + $sw}]

    $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamily)
    # Zeilen vorab bestimmen (Umbruch), damit _ensureSpace korrekt reserviert.
    set rows 1
    set curx $startBx
    foreach o $opts {
        lassign $o val txt
        set w [expr {$boxH + 4 + \
            [pdf4tcllib::text::width $txt $CFG(fontSizeLabel) $CFG(fontFamily)] + 14}]
        if {$curx + $w > $maxX && $curx > $startBx} { incr rows; set curx $startBx }
        set curx [expr {$curx + $w}]
    }
    set totalH [expr {$rows * ($boxH + 3) - 3}]
    ::pdf4tcllib::forms::_ensureSpace $pdf $ctx y \
        [expr {$totalH + $CFG(rowGap)}] $pagebreak

    if {$label ne ""} {
        lassign $CFG(labelColor) lr lg lb
        $pdf setFillColor $lr $lg $lb
        $pdf text $label -x $x -y [expr {$y + $boxH - 3}]
        if {$required} {
            set lw [pdf4tcllib::text::width $label $CFG(fontSizeLabel) $CFG(fontFamily)]
            $pdf setFillColor 0.8 0 0
            $pdf text "*" -x [expr {$x + $lw + 2}] -y [expr {$y + $boxH - 3}]
        }
        $pdf setFillColor 0 0 0
    }

    set curx $startBx
    set cury $y
    $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamily)
    foreach o $opts {
        lassign $o val txt
        set tw [pdf4tcllib::text::width $txt $CFG(fontSizeLabel) $CFG(fontFamily)]
        set w  [expr {$boxH + 4 + $tw + 14}]
        if {$curx + $w > $maxX && $curx > $startBx} {
            set curx $startBx
            set cury [expr {$cury + $boxH + 3}]
        }
        set aa [list -group $group -value $val]
        if {$default ne "" && $val eq $default} { lappend aa -init 1 }
        $pdf addForm radiobutton $curx $cury $boxH $boxH {*}$aa
        $pdf text $txt -x [expr {$curx + $boxH + 4}] -y [expr {$cury + $boxH - 3}]
        set curx [expr {$curx + $w}]
    }
    ::pdf4tcllib::page::_advance $ctx y [expr {$totalH + $CFG(rowGap)}]
}

# Button-Leiste: eine oder mehrere pushbuttons nebeneinander.
# fdef: {type buttons items {{id ID caption "Text" action submit|reset|url ?url ".."?} ..}}
proc ::pdf4tcllib::forms::buttonBar {pdf ctx yVar fdef {pagebreak 0}} {
    upvar 1 $yVar y
    array set CFG [_cfg]
    set items [_getdef $fdef items {}]
    set bh 22
    set x [dict get $ctx SX]
    ::pdf4tcllib::forms::_ensureSpace $pdf $ctx y [expr {$bh + $CFG(rowGap)}] $pagebreak

    $pdf setFont $CFG(fontSize) $CFG(fontFamily)
    set curx $x
    foreach it $items {
        set bid     [_getdef $it id "btn"]
        set caption [_getdef $it caption "Button"]
        set action  [_getdef $it action ""]
        set url     [_getdef $it url ""]
        set bw [expr {[pdf4tcllib::text::width $caption $CFG(fontSize) $CFG(fontFamily)] + 24}]
        if {$bw < 70} { set bw 70 }
        set aa [list -id $bid -caption $caption]
        if {$action ne ""} { lappend aa -action $action }
        if {$url ne ""}    { lappend aa -url $url }
        $pdf addForm pushbutton $curx $y $bw $bh {*}$aa
        set curx [expr {$curx + $bw + 12}]
    }
    ::pdf4tcllib::page::_advance $ctx y [expr {$bh + $CFG(rowGap)}]
}

# Ein Feld aus Dict-Spec (text, combobox, password, ...).
proc ::pdf4tcllib::forms::field {pdf ctx yVar fdef {pagebreak 0}} {
    upvar 1 $yVar y
    array set CFG [_cfg]

    set ftype    [_getdef $fdef type text]
    if {$ftype eq "checkbox"} {
        return [checkboxLine $pdf $ctx y $fdef $pagebreak]
    }
    if {$ftype eq "radio"} {
        return [radioGroup $pdf $ctx y $fdef $pagebreak]
    }
    if {$ftype eq "buttons"} {
        return [buttonBar $pdf $ctx y $fdef $pagebreak]
    }

    set label    [_getdef $fdef label ""]
    set required [_bool [_getdef $fdef required 0]]
    set labelW   [_getdef $fdef labelw $CFG(labelW)]
    set fieldH   [_getdef $fdef fieldh $CFG(fieldH)]
    set fieldW   [_getdef $fdef fieldw {}]
    set multiline [_bool [_getdef $fdef multiline 0]]

    set x  [dict get $ctx SX]
    set sw [dict get $ctx SW]

    # Mehrzeilige Felder: Label auf eigener Zeile oben, Feld in voller Breite
    # darunter. So kann ein langes Label nicht in die Feldbox hineinragen
    # (das Label-links/Feld-rechts-Layout ist nur fuer einzeilige Felder gedacht).
    if {$multiline} {
        set lineH [expr {$CFG(fontSizeLabel) + 4}]
        ::pdf4tcllib::forms::_ensureSpace $pdf $ctx y \
            [expr {$lineH + $fieldH + $CFG(rowGap)}] $pagebreak
        if {$label ne ""} {
            $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamily)
            lassign $CFG(labelColor) lr lg lb
            $pdf setFillColor $lr $lg $lb
            $pdf text $label -x $x -y [expr {$y + $lineH - 2}]
            if {$required} {
                set lw [pdf4tcllib::text::width $label \
                    $CFG(fontSizeLabel) $CFG(fontFamily)]
                $pdf setFont 10 Helvetica-Oblique
                $pdf setFillColor 0.8 0 0
                $pdf text "*" -x [expr {$x + $lw + 2}] -y [expr {$y + $lineH - 2}]
            }
            $pdf setFillColor 0 0 0
            ::pdf4tcllib::page::_advance $ctx y $lineH
        }
        set fw [expr {$fieldW eq {} ? $sw : $fieldW}]
        $pdf setFont $CFG(fontSize) $CFG(fontFamily)
        ::pdf4tcllib::forms::_addForm $pdf $ftype $x $y $fw $fieldH $fdef
        $pdf setFillColor 0 0 0
        ::pdf4tcllib::page::_advance $ctx y [expr {$fieldH + $CFG(rowGap)}]
        return
    }

    ::pdf4tcllib::forms::_ensureSpace $pdf $ctx y [expr {$fieldH + $CFG(rowGap)}] $pagebreak

    if {$fieldW eq {}} {
        set fieldW [expr {$sw - $labelW - $CFG(labelGap)}]
    }

    if {$label ne ""} {
        ::pdf4tcllib::forms::_labelWithRequired $pdf $x $y $label $required $fieldH
    }

    $pdf setFont $CFG(fontSize) $CFG(fontFamily)
    set fx [expr {$x + $labelW + $CFG(labelGap)}]
    ::pdf4tcllib::forms::_addForm $pdf $ftype $fx $y $fieldW $fieldH $fdef
    $pdf setFillColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y [expr {$fieldH + $CFG(rowGap)}]
}

# Tabelle mit optional editierbaren Zellen (addForm text pro Zelle).
proc ::pdf4tcllib::forms::entryTable {pdf ctx yVar tblSpec {pagebreak 0}} {
    upvar 1 $yVar y
    array set CFG [_cfg]

    set headers   [_getdef $tblSpec headers {}]
    set widths    [_getdef $tblSpec widths {}]
    set data      [_getdef $tblSpec rows {}]
    set emptyRows [_getdef $tblSpec emptyRows 0]
    set editable  [_bool [_getdef $tblSpec editable 0]]
    set idPrefix  [_getdef $tblSpec idPrefix f_cell]
    set rowH      [_getdef $tblSpec rowh {}]

    set args {}
    if {$emptyRows > 0} { lappend args -emptyRows $emptyRows }
    if {$rowH ne {}}     { lappend args -rowh $rowH }
    if {[dict exists $tblSpec headerBg]} {
        lappend args -headerBg [dict get $tblSpec headerBg]
    }
    if {$editable} {
        lappend args -cellForm $idPrefix
        # Per-Spalten-Optik: columns {col {align right format {...}} ...}
        # -> addForm-Optionen pro Spalte (nur editierbare Zellen).
        if {[dict exists $tblSpec columns]} {
            set cellOpts {}
            dict for {ci copts} [dict get $tblSpec columns] {
                set oo {}
                foreach k {align color borderwidth bordercolor bgcolor format} {
                    if {[dict exists $copts $k]} {
                        lappend oo -$k [dict get $copts $k]
                    }
                }
                if {[llength $oo]} { dict set cellOpts $ci $oo }
            }
            if {[dict size $cellOpts]} { lappend args -cellOpts $cellOpts }
        }
        # Platz fuer die gesamte Tabelle sichern (optionaler Seitenumbruch).
        set rh [expr {$rowH eq {} ? $CFG(fieldH) : $rowH}]
        set nRows [expr {[llength $data] + $emptyRows}]
        set need  [expr {($rh + 2) + $nRows * $rh + $CFG(rowGap)}]
        ::pdf4tcllib::forms::_ensureSpace $pdf $ctx y $need $pagebreak
    }

    ::pdf4tcllib::form::orderTable $pdf $ctx y $headers $widths $data {*}$args
}

proc ::pdf4tcllib::forms::_renderFieldList {pdf ctx yVar items pagebreak} {
    upvar 1 $yVar y
    foreach item $items {
        if {[llength $item] == 1} { set item [lindex $item 0] }
        if {![catch {dict size $item} n] && $n == 0} continue
        if {![string is list $item] || [catch {dict keys $item} _]} {
            error "pdf4tclforms: field entry must be a dict, got: $item"
        }
        if {[dict exists $item row]} {
            set rowFields {}
            foreach f [dict get $item row] {
                lappend rowFields [::pdf4tcllib::forms::_fieldToRowDict $f]
            }
            ::pdf4tcllib::form::row $pdf $ctx y $rowFields
            continue
        }
        if {[dict exists $item table]} {
            entryTable $pdf $ctx y [dict get $item table] $pagebreak
            continue
        }
        if {[dict exists $item separator]} {
            ::pdf4tcllib::form::separator $pdf $ctx y [_getdef $item separator 4]
            continue
        }
        if {[dict exists $item sums]} {
            foreach s [dict get $item sums] {
                ::pdf4tcllib::forms::_renderSum $pdf $ctx y $s
            }
            continue
        }
        field $pdf $ctx y $item $pagebreak
    }
}

proc ::pdf4tcllib::forms::_fieldToRowDict {fdef} {
    set out [dict create \
        label [_getdef $fdef label ""] \
        type  [_getdef $fdef type text] \
        width [_getdef $fdef width 100]]
    foreach key {id init options readonly multiline labelw fieldh gap \
                 align color borderwidth bordercolor bgcolor calculate format js} {
        if {[dict exists $fdef $key]} {
            dict set out $key [dict get $fdef $key]
        }
    }
    return $out
}

# Rendert einen Summen-Eintrag. Statisch (nur label/value) oder als berechnetes
# Feld, wenn id/calculate/over angegeben ist (-calculate braucht pdf4tcl 0.9.4.32+).
#   id         Feld-Id der Wert-Zelle
#   calculate  {op {feld1 feld2 ...}}  (op: sum|product|average|min|max)
#   over       {idPrefix col count ?start?}  -- Autosumme ueber eine
#              editierbare Tabellenspalte (Zellen idPrefix_row_col)
#   init       statischer Vorabwert (in Nicht-JS-Viewern sichtbar)
proc ::pdf4tcllib::forms::_renderSum {pdf ctx yVar s} {
    upvar 1 $yVar y
    set widths [_getdef $s widths {}]
    set label  [_getdef $s label ""]
    set value  [_getdef $s value ""]
    set id     [_getdef $s id ""]
    set init   [_getdef $s init ""]
    set calc   [_getdef $s calculate ""]
    set fmt    [_getdef $s format ""]
    set js     [_getdef $s js ""]

    if {[dict exists $s over]} {
        lassign [dict get $s over] pfx col count start
        if {$start eq ""} { set start 0 }
        set fields {}
        for {set r $start} {$r < $start + $count} {incr r} {
            lappend fields ${pfx}_${r}_${col}
        }
        if {$calc eq ""} { set calc [list sum $fields] }
        if {$id eq ""}   { set id "${pfx}_sum_${col}" }
    }

    if {$id ne ""} {
        ::pdf4tcllib::form::sumLine $pdf $ctx y $widths $label $value \
            -id $id -calculate $calc -init $init -format $fmt -js $js
    } else {
        ::pdf4tcllib::form::sumLine $pdf $ctx y $widths $label $value
    }
}

proc ::pdf4tcllib::forms::renderSection {pdf ctx yVar sdef {pagebreak 0}} {
    upvar 1 $yVar y
    if {[dict exists $sdef title]} {
        ::pdf4tcllib::form::section $pdf $ctx y [dict get $sdef title]
    }
    if {[dict exists $sdef fields]} {
        ::pdf4tcllib::forms::_renderFieldList $pdf $ctx y \
            [dict get $sdef fields] $pagebreak
    }
    if {[dict exists $sdef table]} {
        entryTable $pdf $ctx y [dict get $sdef table] $pagebreak
    }
    if {[dict exists $sdef sums]} {
        foreach s [dict get $sdef sums] {
            ::pdf4tcllib::forms::_renderSum $pdf $ctx y $s
        }
    }
}

# Haupt-API: komplettes Formular aus Spec-Dict.
proc ::pdf4tcllib::forms::renderSchema {pdf ctx spec args} {
    array set opts {
        -yvar      y
        -pagebreak 0
    }
    array set opts $args
    upvar 1 $opts(-yvar) y

    if {![dict exists $spec sections]} {
        error "pdf4tclforms::renderSchema: spec needs 'sections' key"
    }

    if {[dict exists $spec title]} {
        ::pdf4tcllib::forms::_drawTitle $pdf $ctx y [dict get $spec title]
    }

    dict for {skey sdef} [dict get $spec sections] {
        ::pdf4tcllib::forms::renderSection $pdf $ctx y $sdef $opts(-pagebreak)
    }

    return $y
}

# ---------------------------------------------------------------- templates

proc ::pdf4tcllib::forms::template {name args} {
    switch -exact -- $name {
        callnote   { return [::pdf4tcllib::forms::_tplCallnote {*}$args] }
        inventory  { return [::pdf4tcllib::forms::_tplInventory {*}$args] }
        checklist  { return [::pdf4tcllib::forms::_tplChecklist {*}$args] }
        order      { return [::pdf4tcllib::forms::_tplOrder {*}$args] }
        default {
            error "pdf4tclforms::template: unknown template '$name' \
                (callnote inventory checklist order)"
        }
    }
}

proc ::pdf4tcllib::forms::_tplCallnote {args} {
    array set o {-title "Anrufernotiz"}
    array set o $args
    return [dict create \
        title $o(-title) \
        sections [dict create \
            anruf [dict create \
                title "Anruf" \
                fields {
                    {row {
                        {id f_datum type text label "Datum:" width 120 init ""}
                        {id f_zeit  type text label "Uhrzeit:" width 100 init ""}
                    }}
                    {id f_anrufer type text label "Anrufer:" required 1}
                    {id f_firma   type text label "Firma:"}
                    {id f_tel     type text label "Telefon:" required 1}
                    {id f_email   type text label "E-Mail:"}
                    {id f_betreff type text label "Betreff:"}
                    {id f_notiz   type text label "Notiz:" multiline 1 fieldh 100}
                    {id f_rueck   type checkbox label "Rueckruf erforderlich" init false}
                    {id f_bearb  type text label "Bearbeiter:"}
                }]]]
}

proc ::pdf4tcllib::forms::_tplInventory {args} {
    array set o {-title "PC-Inventar"}
    array set o $args
    return [dict create \
        title $o(-title) \
        sections [dict create \
            geraet [dict create \
                title "Geraet" \
                fields {
                    {id f_invnr    type text label "Inventarnr.:" required 1}
                    {id f_hostname type text label "Hostname:"}
                    {id f_serien   type text label "Seriennummer:"}
                    {id f_modell   type text label "Modell:"}
                    {id f_standort type text label "Standort/Raum:"}
                    {id f_user     type text label "Benutzer:"}
                }] \
            technik [dict create \
                title "Technische Daten" \
                fields {
                    {id f_os   type text label "Betriebssystem:"}
                    {id f_cpu  type text label "CPU:"}
                    {id f_ram  type text label "RAM:"}
                    {id f_disk type text label "Festplatte:"}
                    {id f_ip   type text label "IP-Adresse:"}
                    {id f_mac  type text label "MAC:"}
                }] \
            status [dict create \
                title "Status" \
                fields {
                    {id f_kaufdatum type text label "Kaufdatum:"}
                    {id f_garantie  type text label "Garantie bis:"}
                    {id f_status type combobox label "Status:" \
                        options {"in Betrieb" Lager Defekt ausgemustert}}
                    {id f_bem type text label "Bemerkung:" multiline 1 fieldh 60}
                }]]]
}

proc ::pdf4tcllib::forms::_tplChecklist {args} {
    array set o {
        -title      "Liste zum Eintragen"
        -headers    {Nr Name Bemerkung}
        -widths     {25 200 220}
        -emptyRows  20
    }
    array set o $args
    return [dict create \
        title $o(-title) \
        sections [dict create \
            liste [dict create \
                table [dict create \
                    headers   $o(-headers) \
                    widths    $o(-widths) \
                    emptyRows $o(-emptyRows) \
                    editable  1 \
                    idPrefix  f_list]]]]
}

proc ::pdf4tcllib::forms::_tplOrder {args} {
    array set o {
        -title     "Bestellformular"
        -emptyRows 6
    }
    array set o $args
    return [dict create \
        title $o(-title) \
        sections [dict create \
            kunde [dict create \
                title "Kundendaten" \
                fields {
                    {id f_firma type text label "Firma:" required 1}
                    {id f_name  type text label "Ansprechpartner:"}
                    {id f_mail  type text label "E-Mail:"}
                    {id f_tel   type text label "Telefon:"}
                    {row {
                        {id f_plz  type text label "PLZ:"  width 90}
                        {id f_ort  type text label "Ort:"  width 210}
                    }}
                }] \
            bestellung [dict create \
                title "Positionen" \
                table [dict create \
                    headers   {Pos Artikel Menge Einheit Preis} \
                    widths    {25 210 45 45 70} \
                    emptyRows $o(-emptyRows) \
                    editable  1 \
                    idPrefix  f_pos] \
                sums {
                    {widths {25 210 45 45 70} label "Gesamt:" value ""}
                }]]]
}

# Convenience-Alias (explizite Weiterleitung)
namespace eval ::pdf4tclforms {
    foreach cmd {
        template renderSchema renderSection field checkboxLine entryTable
    } {
        proc $cmd {args} [format {
            uplevel 1 [list ::pdf4tcllib::forms::%s {*}$args]
        } $cmd]
    }
    foreach cmd {
        configure section labelField row separator orderTable sumLine
        fieldHeight rowHeight
    } {
        proc $cmd {args} [format {
            uplevel 1 [list ::pdf4tcllib::form::%s {*}$args]
        } $cmd]
    }
}
