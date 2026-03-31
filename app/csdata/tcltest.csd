title    "tcltest 2.2 -- Cheat Sheet"
subtitle "test, constraint, configure, all.tcl"
sections {
    {title "basic test" type code content {
        {package require tcltest 2.2}
        {namespace import ::tcltest::*}
        {test mytest-1.1 {add} -body { expr {1+1} } -result 2}
        {test mytest-1.2 {upper} -body { string toupper "hi" } -result "HI"}
        {cleanupTests}
    }}
    {title "test options" type table content {
        {{-body}        {-body {code to execute}}             0}
        {{-result}      {-result expectedValue}               0}
        {{-match}       {-match exact|glob|regexp}            0}
        {{-returnCodes} {-returnCodes {ok error}}             0}
        {{-errorCode}   {-errorCode {POSIX ENOENT *}}         0}
        {{-setup}       {-setup {code before body}}           0}
        {{-cleanup}     {-cleanup {code after body}}          0}
        {{-constraints} {-constraints {unix hasDisplay}}      0}
        {{-output}      {-output "expected stdout"}           0}
    }}
    {title "constraints" type table content {
        {define       {testConstraint myConst 1}              1}
        {condition    {testConstraint hasTk [info exists tk_version]} 1}
        {use          {test t-1 {} -constraints hasTk -body {}} 1}
        {notRoot      {testConstraint notRoot [expr {$::tcl_platform(user) ne "root"}]} 1}
        {knownBug     {testConstraint knownBug 0}             1}
        {skip         {-constraints {knownBug}}               0}
        {built-in     {unix win mac unixOrWin knownBug}       0}
    }}
    {title "configure" type table content {
        {verbose      {configure -verbose {body error}}       1}
        {match        {configure -match {mytest-1.*}}         1}
        {skip         {configure -skip {slow-*}}              1}
        {tmpdir       {configure -tmpdir /tmp/tcltest}        1}
    }}
    {title "all.tcl pattern" type code content {
        {package require tcltest 2.2}
        {namespace import ::tcltest::*}
        {configure -testdir [file dirname [file normalize [info script]]]}
        {configure -pattern *.test}
        {runAllTests}
    }}
    {title "assert helpers" type table content {
        {exact        {test t {} -body {expr} -result val}    1}
        {{glob match} {test t {} -match glob -result {fo*}}   1}
        {error        {-returnCodes error -result "msg"}      1}
        {{error code} {-returnCodes error -errorCode {TCL *}} 1}
        {stdout       {-output "expected\n"}                  1}
    }}
    {title "mytest proc pattern" type code content {
        {proc mytest {name desc args} { ... }}
        {    set pattern [dict get $args -result]}
        {    regsub -all { [*] } $pattern {*} pattern}
        {    test $name $desc {*}$args -match glob -result $pattern}
    }}
    {title "tips" type table content {
        {{no puts}    {puts in source -> tcltest counts as error}  0}
        {{destroy}    {always destroy after finish -- avoid truncation} 0}
        {constraint   {testConstraint before test that uses it}    0}
        {tmpdir       {use tcltest::temporaryDirectory for temp files} 1}
        {cleanup      {file delete in -cleanup}                    0}
        {version      {package versions pdf4tcl  ;# check loaded} 1}
    }}
}
