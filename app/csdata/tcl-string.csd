title    "Tcl String Commands -- Cheat Sheet"
subtitle "string, regexp, regsub, format, scan, encoding"
sections {
    {title "string basics" type table content {
        {length     {string length $s}                     1}
        {index      {string index $s 0}                    1}
        {range      {string range $s 2 end}                1}
        {first      {string first "sub" $s ?start?}        1}
        {last       {string last "sub" $s}                 1}
        {reverse    {string reverse $s}                    1}
        {repeat     {string repeat "ab" 3  -> ababab}      1}
        {append     {append var "text"}                    1}
    }}
    {title "string transform" type table content {
        {toupper    {string toupper $s}                    1}
        {tolower    {string tolower $s}                    1}
        {totitle    {string totitle $s}                    1}
        {trim       {string trim $s ?chars?}               1}
        {trimleft   {string trimleft $s}                   1}
        {trimright  {string trimright $s}                  1}
        {map        {string map {a A e E} $s}              1}
        {replace    {string replace $s 2 4 "new"}          1}
    }}
    {title "string test" type table content {
        {equal      {string equal ?-nocase? $a $b}         1}
        {compare    {string compare ?-nocase? $a $b}       1}
        {match      {string match -nocase "foo*" $s}       1}
        {is         {string is integer/double/alpha/... $s} 1}
        {{is alnum}  {string is alnum $s  ;# letters+digits}  1}
        {{is space}  {string is space $s}  1}
    }}
    {title "format / scan" type table content {
        {format     {format "%.2f" 3.14159}                1}
        {format     {format "%05d" 42  -> 00042}           1}
        {format     {format "%-10s|" "hi"  -> "hi        |"} 1}
        {scan       {scan "3.14" "%f" x  ;# x=3.14}       1}
        {{scan multi}  {scan "1 2 3" "%d %d %d" a b c}  1}
    }}
    {title "regexp" type table content {
        {match      {regexp {^\d+$} $s}                    1}
        {capture    {regexp {(\w+)@(\w+)} $s -> u d}       1}
        {{-nocase}  {regexp -nocase {foo} $s}              1}
        {{-all}     {regexp -all {\\d+} $s}                1}
        {{-inline}  {regexp -inline -all {\\d+} $s}        1}
        {anchors    {^ $ start/end  \\b word boundary}     0}
        {classes    {\\d \\w \\s \\D \\W \\S}             1}
    }}
    {title "regsub" type table content {
        {basic      {regsub {\\s+} $s " " result}          1}
        {{-all}     {regsub -all {\\s+} $s "_" result}     1}
        {{-nocase}  {regsub -nocase {foo} $s "bar" r}      1}
        {backrefs   {regsub {(\\w+)} $s {[\1]} r}          1}
        {return     {set s [regsub -all {x} $s "y"]}       1}
    }}
    {title "encoding" type table content {
        {list       {encoding names}                       1}
        {system     {encoding system  ;# current default}  1}
        {convertfrom {encoding convertfrom utf-8 $bytes}  1}
        {convertto  {encoding convertto utf-8 $str}        1}
        {{Tcl 9}  {strings are always Unicode in Tcl 9}  0}
        {binary     {binary scan $bytes H* hex}            1}
    }}
    {title "string tricks" type table content {
        {split      {split "a,b,c" ,  -> {a b c}}          1}
        {join       {join {a b c} ,   -> a,b,c}            1}
        {subst      {subst "1+1=[expr {1+1}]"}             1}
        {{lsearch str} {lsearch -exact $list $str}         1}
        {contains   {string first $sub $s  >= 0}           1}
        {empty      {expr {$s eq {}}}                      1}
    }}
}
