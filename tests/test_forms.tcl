# test_forms.tcl -- pdf4tclforms Spec + Templates (headless wo moeglich)
package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file dirname [file normalize [info script]]]/../lib
package require pdf4tclforms 0.1.1

# ---------------------------------------------------------------- templates

test forms-tpl-callnote-sections "template callnote hat Anruf-Sektion" -body {
    dict exists [pdf4tclforms::template callnote] sections anruf
} -result 1

test forms-tpl-inventory-sections "template inventory hat 3 Sektionen" -body {
    llength [dict keys [dict get [pdf4tclforms::template inventory] sections]]
} -result 3

test forms-tpl-checklist-editable "template checklist ist editierbar" -body {
    set t [pdf4tclforms::template checklist -emptyRows 10]
    set tbl [dict get [dict get [dict get $t sections] liste] table]
    expr {[dict get $tbl editable] && [dict get $tbl emptyRows] == 10}
} -result 1

test forms-tpl-order-positions "template order hat Positionstabelle" -body {
    dict exists [dict get [pdf4tclforms::template order] sections] bestellung
} -result 1

test forms-tpl-unknown "unbekannte Vorlage wirft Fehler" -body {
    set code [catch {pdf4tclforms::template nosuch} msg]
    list $code [string match *unknown* $msg]
} -result {1 1}

# ---------------------------------------------------------------- eigenes Schema (ohne template)

test forms-schema-custom-keys "eigenes Schema braucht sections" -body {
    set spec [dict create title "Test" sections [dict create \
        kopf [dict create title "Kopf" fields {
            {id f1 type text label "Feld:"}
        }]]]
    dict exists $spec sections
} -result 1

test forms-schema-fehlermeldung "Fehlermeldung-Schema hat fuenf Sektionen" -body {
    set demo [file normalize [file join [file dirname [info script]] \
        ../examples/advanced/62_pdf4tclforms_fehlermeldung.tcl]]
    set fp [open $demo r]
    set src [read $fp]
    close $fp
    set idx [string first "\nset outdir " $src]
    uplevel #0 [string range $src 0 [expr {$idx - 1}]]
    llength [dict keys [dict get [schemaFehlermeldung] sections]]
} -result 5 -cleanup {
    catch {rename schemaFehlermeldung {}}
}

test forms-schema-combobox-init "combobox init bleibt String" -body {
    set fdef {id f1 type combobox label "Prio:" options {A B} init Normal}
    set args [::pdf4tcllib::forms::_fieldAddArgs $fdef]
    dict get $args -init
} -result Normal

test forms-schema-checkbox-init "checkbox init wird boolsch" -body {
    set fdef {id c type checkbox init true}
    dict get [::pdf4tcllib::forms::_fieldAddArgs $fdef] -init
} -result 1

# ---------------------------------------------------------------- render (braucht pdf4tcl)

if {![catch {package require pdf4tcl}]} {
    test forms-render-callnote "renderSchema erzeugt gueltiges PDF" -setup {
        set tdir [file dirname [file normalize [info script]]]
        set out [file normalize [file join $tdir out/test_callnote.pdf]]
        file mkdir [file dirname $out]
        set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
        set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
        $pdf startPage
        set y [dict get $ctx top]
    } -body {
        pdf4tclforms::renderSchema $pdf $ctx [pdf4tclforms::template callnote] -yvar y
        $pdf endPage
        $pdf write -file $out
        set v [pdf4tcllib::validate_pdf $out]
        dict get $v valid
    } -cleanup {
        catch {$pdf destroy}
        catch {file delete -force $out}
    } -result 1

    test forms-render-order "renderSchema order erzeugt gueltiges PDF" -setup {
        set tdir [file dirname [file normalize [info script]]]
        set out [file normalize [file join $tdir out/test_order.pdf]]
        file mkdir [file dirname $out]
        set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
        set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
        $pdf startPage
        set y [dict get $ctx top]
    } -body {
        pdf4tclforms::renderSchema $pdf $ctx [pdf4tclforms::template order] -yvar y
        $pdf endPage
        $pdf write -file $out
        set v [pdf4tcllib::validate_pdf $out]
        dict get $v valid
    } -cleanup {
        catch {$pdf destroy}
        catch {file delete -force $out}
    } -result 1

    test forms-render-custom "renderSchema mit eigenem Dict erzeugt gueltiges PDF" -setup {
        set tdir [file dirname [file normalize [info script]]]
        set out [file normalize [file join $tdir out/test_custom.pdf]]
        file mkdir [file dirname $out]
        set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
        set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
        $pdf startPage
        set y [dict get $ctx top]
        set spec [dict create title "Testformular" sections [dict create \
            s1 [dict create title "Daten" fields {
                {row {
                    {id f_datum type text label "Datum:" width 100 init ""}
                    {id f_name  type text label "Name:"  width 180 init ""}
                }}
                {id f_bem type text label "Bemerkung:" multiline 1 fieldh 40}
            }] \
            s2 [dict create \
                title "Liste" \
                table [dict create \
                    headers {Nr Text} widths {30 200} emptyRows 2 editable 1 idPrefix f_c]]]]
    } -body {
        pdf4tclforms::renderSchema $pdf $ctx $spec -yvar y
        $pdf endPage
        $pdf write -file $out
        set v [pdf4tcllib::validate_pdf $out]
        dict get $v valid
    } -cleanup {
        catch {$pdf destroy}
        catch {file delete -force $out}
    } -result 1

    test forms-render-y-advances "renderSchema erhoeht y" -setup {
        set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
        set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
        $pdf startPage
        set y0 [dict get $ctx top]
        set y $y0
    } -body {
        pdf4tclforms::renderSchema $pdf $ctx [pdf4tclforms::template checklist -emptyRows 3] -yvar y
        expr {$y > $y0}
    } -cleanup {
        catch {$pdf destroy}
    } -result 1
} else {
    tcltest::testConstraint pdf4tcl 0
}

cleanupTests
