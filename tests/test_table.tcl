# test_table.tcl -- Tests fuer pdf4tcllib::table
package require tcltest
namespace import ::tcltest::*

# ============================================================
# table::_isDictFormat -- Format-Erkennung
# ============================================================

test table-isdict-list "Listen-Format wird erkannt" -body {
    set data [list {Name Alter} {left right} {Alice 30} {Bob 25}]
    pdf4tcllib::table::_isDictFormat $data
} -result 0

test table-isdict-dict "Dict-Format wird erkannt" -body {
    set data [dict create header {Name Alter} rows {{Alice 30} {Bob 25}} aligns {left right}]
    pdf4tcllib::table::_isDictFormat $data
} -result 1

test table-isdict-dict-nocols "Dict ohne cols-Key ist OK" -body {
    set data [dict create header {Name Alter} rows {{Alice 30}} aligns {left right}]
    pdf4tcllib::table::_isDictFormat $data
} -result 1

test table-isdict-empty "Leere Liste ist kein Dict" -body {
    pdf4tcllib::table::_isDictFormat {}
} -result 0

test table-isdict-partial "Dict ohne rows-Key ist kein Dict" -body {
    set data [dict create header {Name Alter} aligns {left right}]
    # Fehlt "rows" -> kein Dict-Format
    pdf4tcllib::table::_isDictFormat $data
} -result 0

test table-isdict-noaligns "Dict ohne aligns-Key ist kein Dict" -body {
    set data [dict create header {Name Alter} rows {{Alice 30}}]
    # Fehlt "aligns" -> kein Dict-Format
    pdf4tcllib::table::_isDictFormat $data
} -result 0

# ============================================================
# table::_calcColWidths -- Spaltenbreiten
# ============================================================

test table-colw-equal "Gleich lange Spalten -> aehnliche Breiten" -body {
    set header {A B C}
    set aligns {left left left}
    set rows {{xx yy zz} {aa bb cc}}
    set widths [pdf4tcllib::table::_calcColWidths $header $aligns $rows 300 11 Helvetica Helvetica-Bold]
    # Alle 3 Spalten muessen existieren
    llength $widths
} -result 3

test table-colw-sum "Spaltenbreiten summieren sich zu maxW" -body {
    set header {Name Alter Stadt}
    set aligns {left right left}
    set rows {{Alice 30 Berlin} {Bob 25 Hamburg}}
    set widths [pdf4tcllib::table::_calcColWidths $header $aligns $rows 400 11 Helvetica Helvetica-Bold]
    set sum 0
    foreach w $widths { set sum [expr {$sum + $w}] }
    # Summe sollte <= maxW sein
    expr {$sum <= 400.1}
} -result 1

test table-colw-no-header "Ohne Header: Spaltenanzahl von erster Zeile" -body {
    set header {}
    set aligns {left left}
    set rows {{Alice 30} {Bob 25}}
    set widths [pdf4tcllib::table::_calcColWidths $header $aligns $rows 300 11 Helvetica Helvetica-Bold]
    llength $widths
} -result 2

test table-colw-wide-col "Breite Spalte bekommt mehr Platz" -body {
    set header {Kurz Sehr_langer_Spalteninhalt_hier}
    set aligns {left left}
    set rows {{x Donaudampfschifffahrtsgesellschaftskapitaen}}
    set widths [pdf4tcllib::table::_calcColWidths $header $aligns $rows 400 11 Helvetica Helvetica-Bold]
    # Zweite Spalte sollte breiter als erste sein
    expr {[lindex $widths 1] > [lindex $widths 0]}
} -result 1

# ============================================================
# table::render -- pageBreakCmd hook (host-driven pagination)
# ============================================================

proc ::tblHookCb {} {
    incr ::pb_calls
    $::pb_pdf endPage
    $::pb_pdf startPage
    return $::pb_top
}

test table-pagebreak-hook "pageBreakCmd drives pagination; internal pageNo untouched" -constraints pdf -setup {
    set ::pb_calls 0
} -body {
    set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf startPage
    set margin 40.0 ; set pageW 595.0 ; set pageH 842.0
    set x0 $margin ; set maxW [expr {$pageW - 2 * $margin}]
    set yTop $margin ; set yBot [expr {$yTop + 120}]  ;# tiny band -> forces breaks
    set ::pb_pdf $pdf ; set ::pb_top $yTop
    set y $yTop ; set internalPageNo 1
    set rows {}
    for {set i 0} {$i < 40} {incr i} { lappend rows [list "row$i" "value-$i" [expr {$i * 7}]] }
    set tableData [dict create header {Key Value Num} rows $rows aligns {left left right}]
    pdf4tcllib::table::render $pdf $tableData $x0 y $maxW $yTop $yBot internalPageNo \
        $pageW $pageH $margin 9 12 0 {::tblHookCb}
    $pdf destroy
    # callback fired, and render left the internal page counter alone
    list [expr {$::pb_calls > 0}] $internalPageNo
} -result {1 1} -cleanup {
    unset -nocomplain ::pb_calls ::pb_pdf ::pb_top
}

test table-pagebreak-legacy "no pageBreakCmd: internal pagination increments" -constraints pdf -body {
    set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
    $pdf startPage
    set margin 40.0 ; set pageW 595.0 ; set pageH 842.0
    set x0 $margin ; set maxW [expr {$pageW - 2 * $margin}]
    set yTop $margin ; set yBot [expr {$yTop + 120}]
    set y $yTop ; set pno 1
    set rows {}
    for {set i 0} {$i < 40} {incr i} { lappend rows [list "row$i" "value-$i" $i] }
    set tableData [dict create header {Key Value Num} rows $rows aligns {left left right}]
    pdf4tcllib::table::render $pdf $tableData $x0 y $maxW $yTop $yBot pno \
        $pageW $pageH $margin 9 12
    $pdf destroy
    expr {$pno > 1}
} -result 1

# ============================================================
# Tagged PDF -- pdf4tcllib::tag and the table structure
# ============================================================
# The table is where tagging pays off most: without it a screen reader
# announces a run of unrelated numbers instead of a table it can navigate by
# row and column. Tagging is not switched on here, the caller does that with
# "$pdf tagged 1"; when it is off every helper does nothing.

proc tagTestPdf {} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 40 -orient 1 -compress 0]
    $pdf tagged 1 -lang de-DE
    $pdf startPage
    $pdf setFont 10 Helvetica
    return $pdf
}

# pdf4tcl is the one external dependency. Tests that need it are marked,
# so that a fresh clone WITHOUT pdf4tcl reports skips rather than failures
# -- a red suite is how a new reader decides the library is broken.
testConstraint pdf [expr {![catch {package require pdf4tcl}]}]

proc tagTableData {} {
    return [list {Artikel Menge Preis} {left right right} \
            {Schraube 100 4,90} {Mutter 200 3,50}]
}

test table-tag-off "ohne tagged bleibt alles unveraendert" -constraints pdf -body {
    # The important half of the feature: existing code must not change.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 40 -orient 1 -compress 0]
    $pdf startPage
    $pdf setFont 10 Helvetica
    set y 40 ; set pno 1
    ::pdf4tcllib::table::render $pdf [tagTableData] 0 y 500 20 750 pno \
            595 842 40 10 12
    set data [$pdf get]
    $pdf destroy
    # no marked content, no structure tree
    list [string first "BDC" $data] [string first "/StructTreeRoot" $data]
} -result {-1 -1}

test table-tag-structure "mit tagged entsteht Table/TR/TH/TD" -constraints pdf -body {
    set pdf [tagTestPdf]
    set y 40 ; set pno 1
    ::pdf4tcllib::table::render $pdf [tagTableData] 0 y 500 20 750 pno \
            595 842 40 10 12
    set data [$pdf get]
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    list [expr {[string first "/S /Table" $data] >= 0}] \
            [expr {[string first "/S /TR" $data] >= 0}] \
            [expr {[string first "/S /TH" $data] >= 0}] \
            [expr {[string first "/S /TD" $data] >= 0}]
} -result {1 1 1 1}

test table-tag-scope "Kopfzellen tragen /Scope Column" -constraints pdf -body {
    # ISO 14289-1 clause 7.5 wants /Scope wherever the header relation cannot
    # be derived from the layout, which is the case for a single header row.
    set pdf [tagTestPdf]
    set y 40 ; set pno 1
    ::pdf4tcllib::table::render $pdf [tagTableData] 0 y 500 20 750 pno \
            595 842 40 10 12
    set data [$pdf get]
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    expr {[string first "/Scope /Column" $data] >= 0}
} -result 1

test table-tag-artifacts "Gitterlinien und Zebrastreifen sind Artefakte" -constraints pdf -body {
    # Decoration announced as content is worse than no tagging at all.
    set pdf [tagTestPdf]
    set y 40 ; set pno 1
    ::pdf4tcllib::table::render $pdf [tagTableData] 0 y 500 20 750 pno \
            595 842 40 10 12
    set data [$pdf get]
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    expr {[string first "/Artifact" $data] >= 0}
} -result 1

test table-tag-noprobe "die Erkennung hinterlaesst kein leeres Element" -constraints pdf -body {
    # The probe used to be a tagBegin/tagEnd pair, which left an empty Span
    # sitting in the tree next to the table. tagArtifact answers the same
    # question and creates no element.
    set pdf [tagTestPdf]
    set y 40 ; set pno 1
    ::pdf4tcllib::table::render $pdf [tagTableData] 0 y 500 20 750 pno \
            595 842 40 10 12
    set data [$pdf get]
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    expr {[string first "/S /Span" $data] < 0}
} -result 1

proc tagDrawCols {} {
    return [list [list -header Artikel -width 120] \
            [list -header Menge -align right] \
            [list -header Preis -align right]]
}

test table-tag-draw "table::draw zeichnet ebenfalls aus" -constraints pdf -body {
    # draw is the richer implementation -- footer, cell styles, row indent --
    # and pdf4tcltable delegates to it, so tagging here covers the tablelist
    # export as well.
    set pdf [tagTestPdf]
    ::pdf4tcllib::table::draw $pdf 0 40 [tagDrawCols] \
            {{Schraube 100 4,90} {Mutter 200 3,50}} -zebra 1
    set data [$pdf get]
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    list [expr {[string first "/S /Table" $data] >= 0}] \
            [expr {[string first "/S /TH" $data] >= 0}] \
            [expr {[string first "/S /TD" $data] >= 0}] \
            [expr {[string first "/Scope /Column" $data] >= 0}]
} -result {1 1 1 1}

test table-tag-draw-footer "die Fusszeile ist eine eigene TR" -constraints pdf -body {
    set pdf [tagTestPdf]
    ::pdf4tcllib::table::draw $pdf 0 40 [tagDrawCols] \
            {{Schraube 100 4,90}} -footer {Summe {} 4,90}
    set data [$pdf get]
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    # header row + one data row + footer row
    set n 0
    foreach _ [regexp -all -inline {/S /TR} $data] { incr n }
    set n
} -result 3

test table-tag-draw-off "ohne tagged bleibt draw unveraendert" -constraints pdf -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 40 -orient 1 -compress 0]
    $pdf startPage
    $pdf setFont 10 Helvetica
    ::pdf4tcllib::table::draw $pdf 0 40 [tagDrawCols] \
            {{Schraube 100 4,90}} -zebra 1 -footer {Summe {} 4,90}
    set data [$pdf get]
    $pdf destroy
    list [string first "BDC" $data] [string first "/StructTreeRoot" $data]
} -result {-1 -1}

# ============================================================
# Tablelist-Export -- der Adapterweg
# ============================================================
# pdf4tcltable liest das Widget aus und delegiert an table::draw. Weil draw
# auszeichnet, ist der Export mit erledigt -- ohne eine Zeile in
# pdf4tcltable. Diese Tests belegen das an einem echten Widget.

testConstraint tablelist [expr {![catch {
    package require Tk
    package require tablelist_tile
    package require pdf4tcltable
}]}]

proc tagTablelistWidget {} {
    destroy .tagtl
    tablelist::tablelist .tagtl \
            -columns {0 "Artikel" left 0 "Menge" right 0 "Preis" right} \
            -stretch all -height 5
    .tagtl insert end {Schraube 100 4,90}
    .tagtl insert end {Mutter 200 3,50}
    pack .tagtl
    update
    return .tagtl
}

test table-tag-tablelist "Tablelist-Export traegt die Struktur" \
        -constraints tablelist -body {
    set tbl [tagTablelistWidget]
    set pdf [tagTestPdf]
    ::pdf4tcllib::tablelist::render $pdf $tbl 0 40
    set data [$pdf get]
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    destroy $tbl
    list [expr {[string first "/S /Table" $data] >= 0}] \
            [expr {[string first "/S /TH" $data] >= 0}] \
            [expr {[string first "/S /TD" $data] >= 0}] \
            [expr {[string first "/Scope /Column" $data] >= 0}]
} -result {1 1 1 1}

test table-tag-tablelist-off "ohne tagged bleibt der Export unveraendert" \
        -constraints tablelist -body {
    set tbl [tagTablelistWidget]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 40 -orient 1 -compress 0]
    $pdf startPage
    $pdf setFont 10 Helvetica
    ::pdf4tcllib::tablelist::render $pdf $tbl 0 40
    set data [$pdf get]
    $pdf destroy
    destroy $tbl
    list [string first "BDC" $data] [string first "/StructTreeRoot" $data]
} -result {-1 -1}

# ============================================================
# Formularfelder -- pdf4tcllib::form und pdf4tclforms
# ============================================================

testConstraint forms [expr {![catch {package require pdf4tclforms}]}]

test form-tag-field "labelField haengt das Feld in ein Form-Element" \
        -constraints forms -body {
    # Ein Formularfeld ist eine Annotation. Ausserhalb eines
    # Strukturelements ist es vom Baum aus nicht erreichbar: anklicken geht,
    # ein Screenreader findet es nie.
    set pdf [tagTestPdf]
    set ctx [::pdf4tcllib::page::context a4 -margin 25 -orient true]
    set y 60
    ::pdf4tcllib::form::labelField $pdf $ctx y "Name" text -id nm
    set data [$pdf get]
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    list [expr {[string first "/S /Form" $data] >= 0}] \
            [expr {[string first "/OBJR" $data] >= 0}] \
            [expr {[string first "(Name)" $data] >= 0}]
} -result {1 1 1}

test form-tag-off "ohne tagged bleiben Formulare unveraendert" \
        -constraints forms -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0]
    $pdf startPage
    $pdf setFont 10 Helvetica
    set ctx [::pdf4tcllib::page::context a4 -margin 25 -orient true]
    set y 60
    ::pdf4tcllib::form::labelField $pdf $ctx y "Name" text -id nm
    set data [$pdf get]
    $pdf destroy
    list [string first "BDC" $data] [string first "/StructTreeRoot" $data]
} -result {-1 -1}

test form-tag-no-warning "ein ausgezeichnetes Formular loest keine Warnung aus" \
        -constraints forms -body {
    # Die Warnung aus pdf4tcl 0.9.4.39 ist der Massstab: verstummt sie, ist
    # das Feld tatsaechlich angebunden.
    set ::pdf4tcl::warnings {}
    set pdf [tagTestPdf]
    set ctx [::pdf4tcllib::page::context a4 -margin 25 -orient true]
    set y 60
    ::pdf4tcllib::form::labelField $pdf $ctx y "Name" text -id nm
    $pdf get
    $pdf destroy
    ::pdf4tcllib::tag::forget $pdf
    llength $::pdf4tcl::warnings
} -cleanup {
    set ::pdf4tcl::warnings {}
} -result 0

# ============================================================
# Schriftuebersteuerung -- -font / -boldfont bis in die Datei
# ============================================================
#
# Bis 0.3 nahm der Adapter beide Optionen an und wandte sie nicht an. Ein
# Test auf "wird angenommen" haette das nicht gemerkt; gemessen wird deshalb
# der eingebettete Fontname in der erzeugten Datei.

proc tableFontsInPdf {file} {
    set fh [open $file rb]
    set d [read $fh]
    close $fh
    set out {}
    foreach {full name} [regexp -all -inline {/BaseFont\s*/([A-Za-z0-9+,-]+)} $d] {
        lappend out $name
    }
    return [lsort -unique $out]
}

proc tableRenderWith {args} {
    set out [file join [file dirname [info script]] out zz-fontovr.pdf]
    file mkdir [file dirname $out]
    set t [tablelist::tablelist .__fo -columns {10 A left 8 B right} -showlabels 1]
    $t insert end {Kaffee 12}
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    ::pdf4tcllib::tablelist::render $pdf $t 40 700 -maxwidth 300 {*}$args
    $pdf write -file $out
    $pdf destroy
    destroy $t
    set fonts [tableFontsInPdf $out]
    file delete $out
    return $fonts
}

test table-fontovr-1 "ohne Uebersteuerung der Satz aus fonts::init" \
        -constraints tablelist -body {
    tableRenderWith
} -result {Helvetica Helvetica-Bold}

test table-fontovr-2 "-font ersetzt den regulaeren Schnitt" \
        -constraints tablelist -body {
    tableRenderWith -font Times-Roman
} -result {Helvetica-Bold Times-Roman}

test table-fontovr-3 "-boldfont ersetzt den fetten Schnitt" \
        -constraints tablelist -body {
    tableRenderWith -boldfont Courier-Bold
} -result {Courier-Bold Helvetica}

test table-fontovr-4 "beide zusammen" -constraints tablelist -body {
    tableRenderWith -font Times-Roman -boldfont Times-Bold
} -result {Times-Bold Times-Roman}


cleanupTests
