title    "Tcl File & I/O -- Cheat Sheet"
subtitle "open, read, write, file, glob, channels, encoding"
sections {
    {title "open / close" type table content {
        {read        {set f [open $path r]  ;# read}        1}
        {write       {set f [open $path w]  ;# write}       1}
        {append      {set f [open $path a]  ;# append}      1}
        {read+write  {set f [open $path r+]}                1}
        {binary      {open $path rb  ;# binary read}        1}
        {close       {close $f}                             1}
        {encoding    {fconfigure $f -encoding utf-8}        1}
        {translation {fconfigure $f -translation lf}        1}
    }}
    {title "read / write" type table content {
        {{read all}  {set data [read $f]}  1}
        {{read n}  {set chunk [read $f 4096]}  1}
        {gets        {gets $f line  ;# one line}            1}
        {getlines    {while {[gets $f l] >= 0} { ... }}     1}
        {puts        {puts $f "text"}                       1}
        {{puts no nl} {puts -nonewline $f "text"}           1}
        {flush       {flush $f}                             1}
        {seek        {seek $f 0  ;# rewind}                 1}
        {tell        {tell $f  ;# current position}         1}
        {eof         {eof $f}                               1}
    }}
    {title "file info" type table content {
        {exists      {file exists $path}                    1}
        {isfile      {file isfile $path}                    1}
        {isdir       {file isdirectory $path}               1}
        {size        {file size $path}                      1}
        {mtime       {file mtime $path}                     1}
        {readable    {file readable $path}                  1}
        {writable    {file writable $path}                  1}
        {type        {file type $path  ;# file/dir/link}    1}
        {stat        {file stat $path arr  ;# full stat}    1}
    }}
    {title "path manipulation" type table content {
        {join        {file join dir subdir file.txt}        1}
        {dirname     {file dirname $path}                   1}
        {tail        {file tail $path  ;# filename only}    1}
        {rootname    {file rootname file.txt  -> file}      1}
        {extension   {file extension file.txt  -> .txt}     1}
        {normalize   {file normalize ~/myfile}              1}
        {nativename  {file nativename $path}                1}
        {{Tcl 9 warn}  {file normalize ~ unreliable -- use $env(HOME)}  0}
    }}
    {title "file operations" type table content {
        {copy        {file copy $src $dst}                  1}
        {rename      {file rename $src $dst}                1}
        {delete      {file delete $path}                    1}
        {{delete -force} {file delete -force $dir}          1}
        {mkdir       {file mkdir $dir}                      1}
        {link        {file link $link $target}              1}
        {glob        {glob *.tcl}                           1}
        {{glob -dir} {glob -dir $dir -type f *.tcl}         1}
        {{glob -nocomplain} {glob -nocomplain *.pdf}        1}
    }}
    {title "channels" type table content {
        {stdin       {gets stdin line}                      1}
        {stdout      {puts stdout "text"}                   1}
        {stderr      {puts stderr "error"}                  1}
        {pipe        {set f [open "| cmd" r]}               1}
        {{pipe write}  {set f [open "| cmd" w]}  1}
        {nonblock    {fconfigure $f -blocking 0}            1}
        {fileevent   {fileevent $f readable {handler $f}}   1}
        {{string chan}  {package require tcl::chan::string}  1}
    }}
    {title "read file patterns" type table content {
        {slurp       {set d [read [set f [open $p]]; close $f; set d} 1}
        {lines       {split [read $f] \n}                   1}
        {{binary read}  {fconfigure $f -translation binary}  1}
        {try/finally {try { read $f } finally { close $f }} 1}
    }}
}
