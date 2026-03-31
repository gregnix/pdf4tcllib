title    "Tcl List & Dict -- Cheat Sheet"
subtitle "list, lsearch, lsort, lmap, dict"
sections {
    {title "list build" type table content {
        {list        {list a b c  ;# safe quoting}           1}
        {lappend     {lappend var a b c}                     1}
        {linsert     {linsert $l 2 "x"}                     1}
        {lreplace    {lreplace $l 1 2 "new"}                1}
        {concat      {concat $l1 $l2}                        1}
        {lrepeat     {lrepeat 3 0  -> {0 0 0}}               1}
    }}
    {title "list access" type table content {
        {lindex       {lindex $l 0}                          1}
        {{lindex nest} {lindex $l 0 1  ;# nested}           1}
        {llength      {llength $l}                           1}
        {lrange       {lrange $l 1 end}                      1}
        {lassign      {lassign $l a b c}                     1}
        {lreverse     {lreverse $l}                          1}
        {lset         {lset l 2 "new"}                       1}
    }}
    {title "list search" type table content {
        {lsearch      {lsearch $l "foo"}                     1}
        {{-exact}     {lsearch -exact $l $val}               1}
        {{-glob}      {lsearch -glob $l "fo*"}               1}
        {{-regexp}    {lsearch -regexp $l {^\d+}}            1}
        {{-nocase}    {lsearch -nocase $l "Foo"}             1}
        {{-all}       {lsearch -all $l $val}                 1}
        {{-inline}    {lsearch -inline -all $l "fo*"}        1}
        {lcontain     {expr {$val in $l}}                    1}
    }}
    {title "list sort" type table content {
        {lsort        {lsort $l  ;# alpha ascending}         1}
        {{-integer}   {lsort -integer $l}                    1}
        {{-real}      {lsort -real $l}                       1}
        {{-decr}      {lsort -decreasing $l}                 1}
        {{-nocase}    {lsort -nocase $l}                     1}
        {{-unique}    {lsort -unique $l}                     1}
        {{-index}     {lsort -index 1 $l}                    1}
        {{-command}   {lsort -command myCompare $l}          1}
    }}
    {title "list functional" type table content {
        {foreach      {foreach item $l { ... }}               1}
        {lmap         {lmap x $l {expr {$x * 2}}}            1}
        {{lmap pair}  {lmap {k v} $pairs {list $v $k}}       1}
        {lfilter      {lmap x $l {if {$x>0} {set x} continue}} 1}
        {apply        {apply {x {expr {$x+1}}} 5}            1}
    }}
    {title "dict build" type table content {
        {create       {dict create k1 v1 k2 v2}              1}
        {{dict set}   {dict set d key value}                  1}
        {unset        {dict unset d key}                     1}
        {merge        {dict merge $d1 $d2}                   1}
        {update       {dict update d k v { set v new }}       1}
        {append       {dict append d key " more"}             1}
        {incr         {dict incr d counter}                  1}
    }}
    {title "dict access" type table content {
        {get          {dict get $d key}                       1}
        {{get nested} {dict get $d a b c}                    1}
        {exists       {dict exists $d key}                   1}
        {keys         {dict keys $d ?pattern?}               1}
        {values       {dict values $d}                       1}
        {size         {dict size $d}                         1}
        {{dict for}   {dict for {k v} $d { ... }}             1}
        {filter       {dict filter $d value "fo*"}            1}
    }}
    {title "dict patterns" type table content {
        {default      {set v [dict get $d k]  ;# error if missing} 1}
        {{safe get}   {if {[dict exists $d k]} {dict get $d k}}    1}
        {with         {dict with d { puts $key }}                  1}
        {{nested set} {dict set d a b c "val"}                     1}
        {{auto incr}  {dict incr d hits  ;# creates if missing}    1}
    }}
}
