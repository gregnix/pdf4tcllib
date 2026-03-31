title    "Tcl format & scan -- Cheat Sheet"
subtitle "format, scan, binary scan, binary format"
sections {
    {title "format -- Zahlen" type table content {
        {{%d}         {format "%d" 42        -> 42}            1}
        {{%05d}       {format "%05d" 42      -> 00042}         1}
        {{%-10d}      {format "%-10d|" 42    -> "42        |"} 1}
        {{%+d}        {format "%+d" 42       -> +42}           1}
        {{%x}         {format "%x" 255       -> ff}            1}
        {{%X}         {format "%X" 255       -> FF}            1}
        {{%08x}       {format "%08x" 255     -> 000000ff}      1}
        {{%o}         {format "%o" 8         -> 10}            1}
        {{%b}         {format "%b" 10        -> 1010}          1}
    }}
    {title "format -- Gleitkomma" type table content {
        {{%f}         {format "%f" 3.14159   -> 3.141590}      1}
        {{%.2f}       {format "%.2f" 3.14159 -> 3.14}          1}
        {{%10.2f}     {format "%10.2f" 3.14  -> "      3.14"} 1}
        {{%e}         {format "%e" 12345.0   -> 1.234500e+04}  1}
        {{%.3e}       {format "%.3e" 12345.0 -> 1.234e+04}     1}
        {{%g}         {format "%g" 0.00123   -> 0.00123}       1}
        {{%g large}   {format "%g" 1234567.0 -> 1.23457e+06}   1}
    }}
    {title "format -- Strings" type table content {
        {{%s}         {format "%s" "hello"   -> hello}         1}
        {{%10s}       {format "%10s" "hi"    -> "        hi"}  1}
        {{%-10s}      {format "%-10s|" "hi"  -> "hi        |"} 1}
        {{%.3s}       {format "%.3s" "hello" -> hel}           1}
        {{%c}         {format "%c" 65        -> A}             1}
    }}
    {title "format -- Mehrere Argumente" type table content {
        {{multi}      {format "%s: %d" "count" 42 -> "count: 42"}  1}
        {{padding}    {format "%-8s %5.2f" "pi" 3.14159}           1}
        {{repeat %1$} {format "%1\$s %1\$s" "echo" -> "echo echo"} 1}
        {{%% literal} {format "100%% done"  -> "100% done"}        1}
    }}
    {title "scan -- Zahlen" type table content {
        {{%d}         {scan "42" "%d" x    ;# x=42}            1}
        {{%f}         {scan "3.14" "%f" x  ;# x=3.14}          1}
        {{%x}         {scan "ff" "%x" x    ;# x=255}           1}
        {{%o}         {scan "10" "%o" x    ;# x=8}             1}
        {return       {scan returns # of matched items}         0}
        {{no var}     {set n [scan "42" "%d"]  ;# n=42}         1}
    }}
    {title "scan -- Mehrere Felder" type table content {
        {{multi}      {scan "1 2 3" "%d %d %d" a b c}          1}
        {{string}     {scan "hello 42" "%s %d" s n}            1}
        {{date}       {scan "2026-03-31" "%d-%d-%d" y m d}     1}
        {{partial}    {scan "a b c" "%s %s" x  ;# returns 1}   1}
        {{skip %*}    {scan "1 2 3" "%d %*d %d" a b  ;# skip middle} 1}
        {{width}      {scan "hello" "%3s" x  ;# x=hel}         1}
    }}
    {title "scan -- Zeichenklassen" type table content {
        {{%[az]}      {scan "hello!" "%\[a-z\]" x  ;# x=hello}  1}
        {{%[^\ ]}     {scan "hello world" "%\[^ \]" x  ;# x=hello} 1}
        {{%c}         {scan "A" "%c" x  ;# x=65}               1}
        {{match all}  {scan "abc123" "%\[a-z\]%\[0-9\]" s n}   1}
    }}
    {title "binary format" type table content {
        {{c}          {binary format c 65    ;# 1 byte}         1}
        {{s}          {binary format s 256   ;# 2 bytes LE}     1}
        {{S}          {binary format S 256   ;# 2 bytes BE}     1}
        {{i}          {binary format i 1000  ;# 4 bytes LE}     1}
        {{I}          {binary format I 1000  ;# 4 bytes BE}     1}
        {{w}          {binary format w $n    ;# 8 bytes LE}     1}
        {{f}          {binary format f 3.14  ;# float 4 bytes}  1}
        {{d}          {binary format d 3.14  ;# double 8 bytes} 1}
        {{a}          {binary format a5 "hello"  ;# 5 bytes}    1}
        {{H}          {binary format H* "ff00"   ;# hex->bytes} 1}
    }}
    {title "binary scan" type table content {
        {{c}          {binary scan $b c x   ;# 1 signed byte}   1}
        {{cu}         {binary scan $b cu x  ;# 1 unsigned byte}  1}
        {{su}         {binary scan $b su x  ;# 2 bytes BE unsigned} 1}
        {{iu}         {binary scan $b iu x  ;# 4 bytes BE unsigned} 1}
        {{W}          {binary scan $b W x   ;# 8 bytes BE signed}  1}
        {{Wu sign}    {set W [expr {$W & 0xFFFFFFFFFFFFFFFF}]}   1}
        {{f}          {binary scan $b f x   ;# float}           1}
        {{H*}         {binary scan $b H* hex  ;# all as hex}    1}
        {{@}          {binary scan $b @4iu x  ;# skip 4 bytes}  1}
        {multi        {binary scan $b IuIu a b  ;# two uint32}  1}
    }}
    {title "Tipps & Fallen" type table content {
        {Genauigkeit  {%.15g fuer max. Genauigkeit}              0}
        {Tausender    {kein %,d in Tcl -- manuell formatieren}   0}
        {{scan Liste} {split + scan kombo: foreach x $list ...}  0}
        {{W signed}   {binary scan W gibt signed -- & 0xFF...FF fuer unsigned} 0}
        {encoding     {binary scan/format: immer bytes, kein encoding} 0}
        {Tcl9         {kein binary scan W Problem in Tcl 9 (64-bit native)} 0}
    }}
}
