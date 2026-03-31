title    "Tcl apply & Lambda -- Cheat Sheet"
subtitle "apply, anonyme Funktionen, Closures, funktionale Muster"
sections {
    {title "apply Grundform" type table content {
        {Syntax      {apply {{args} body} ?arg ...?}            1}
        {{1 Arg}     {apply {{x} {expr {$x * 2}}} 5  -> 10}    1}
        {{2 Args}    {apply {{x y} {expr {$x + $y}}} 3 4}       1}
        {{kein Arg}  {apply {{} {puts "hello"}}}                1}
        {{varargs}   {apply {{args} {llength $args}} a b c}     1}
        {Rückgabe    {apply gibt Rückgabewert des body zurück}   0}
    }}
    {title "Lambda als Variable" type code content {
        {# Lambda in Variable speichern}
        {set double {{x} {expr {$x * 2}}}}
        {apply $double 7       ;# -> 14}
        {}
        {set add {{x y} {expr {$x + $y}}}}
        {apply $add 3 4        ;# -> 7}
        {}
        {# Als Listenwert übergeben}
        {set ops [list $double $add]}
        {apply [lindex $ops 0] 5  ;# -> 10}
    }}
    {title "Namespace-Argument" type table content {
        {Syntax      {apply {{args} body ns} ?arg ...?}          1}
        {Zweck       {body wird in Namespace ns ausgeführt}       0}
        {{global ns} {apply {{x} {set ::g $x}} :: 42}            1}
        {{eigener ns} {apply {{x} {set y $x}} ::myns 5}          1}
        {Standard    {ohne ns: aktueller Namespace}               0}
    }}
    {title "lmap mit Lambda" type code content {
        {# Elemente transformieren}
        {set nums {1 2 3 4 5}}
        {lmap x $nums {expr {$x * $x}}  ;# {1 4 9 16 25}}
        {}
        {# apply + lmap}
        {set sq {{x} {expr {$x * $x}}}}
        {lmap x $nums {apply $sq $x}}
        {}
        {# Filtern (Tcl 8.6+)}
        {lmap x $nums {if {$x > 2} {set x} {continue}}}
    }}
    {title "Closures (manuell)" type code content {
        {# Tcl hat keine echten Closures -- Variable einbetten}
        {set factor 3}
        {set mult [list {x factor} {expr {$x * $factor}} $factor]}
        {apply $mult 7  ;# -> 21}
        {}
        {# Allgemeine Closure-Fabrik}
        {proc make_adder {n} {}
        {    list {x n} {expr {$x + $n}} $n}
        {set add5 [make_adder 5]}
        {apply $add5 10  ;# -> 15}
    }}
    {title "Closure-Fabrik Muster" type code content {
        {proc make_multiplier {factor} {}
        {    return [list {x f} {expr {$x * $f}} $factor]}
        {}
        {set double [make_multiplier 2]}
        {set triple [make_multiplier 3]}
        {apply $double 7   ;# -> 14}
        {apply $triple 7   ;# -> 21}
        {}
        {# Namespace-Closure}
        {proc make_counter {{start 0}} {}
        {    set ns [namespace eval [namespace current]::c {}] }
        {    namespace eval $ns [list variable n $start]       }
        {    return [list {} {variable n; incr n} $ns]         }
    }}
    {title "apply als Callback" type code content {
        {# Callback übergeben}
        {proc each {list fn} { foreach x $list { apply $fn $x } }}
        {}
        {each {1 2 3} {{x} { puts "item: $x" }}}
        {}
        {# Mit lsort -command}
        {set cmp {{a b} {string compare $a $b}}}
        {lsort -command $cmp {banana apple cherry}}
        {}
        {# Pipe-Muster}
        {proc pipe {val args} {}}
        {    foreach fn $args { set val [apply $fn $val] }     }
        {    return $val                                        }
        {pipe 3  {{x} {expr {$x*2}}}  {{x} {expr {$x+1}}}}
    }}
    {title "Vergleich proc vs apply" type table content {
        {{proc}      {proc name {args} {body}  ;# global}      1}
        {{apply}     {apply {{args} body} ?arg?  ;# anonym}    1}
        {Sichtbarkeit {proc: global; apply: aktueller Scope}    0}
        {{Rekursion} {apply: [self] nicht verfügbar -- nutze proc} 0}
        {Performance {proc etwas schneller bei Wiederholung}    0}
        {Tcl-Version {apply ab Tcl 8.5}                         0}
    }}
    {title "Häufige Muster" type table content {
        {einmalig    {apply {{} { ... }}  ;# sofort ausführen}  1}
        {transform   {lmap x $l {apply $fn $x}}                 1}
        {reduce      {set acc [apply $fn $acc $x]}               1}
        {dispatch    {dict set handlers key {{a} {body}}}        1}
        {{call handler} {apply [dict get $handlers $key] $arg}  1}
        {{default arg} {apply {{x {def 0}} {expr {$x+$def}}} 5} 1}
    }}
    {title "Fallen & Hinweise" type table content {
        {Arity       {falsche Argzahl -> Fehler wie bei proc}   0}
        {{kein self} {kein Zugriff auf [self] / [info level]}   0}
        {{var scope} {upvar/uplevel relativ zum apply-Aufruf}   0}
        {Closures    {eingebettete Werte -> dritter Listeneintrag} 0}
        {{kein name} {apply hat keinen Prozedurenamen -- stack zeigt {}} 0}
        {Alternative {Tcl 9: noch kein echter Lambda-Typ -- apply bleibt Idiom} 0}
    }}
}
