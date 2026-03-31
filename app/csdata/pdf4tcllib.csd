title    "pdf4tcllib 0.2 -- Cheat Sheet"
subtitle "fonts, page::context, text, table, drawing, form"
sections {
    {title "setup" type code content {
        {tcl::tm::path add /path/to/lib}
        {package require pdf4tcllib 0.2}
        {pdf4tcllib::fonts::init  ;# find TTF fonts}
        {set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]}
        {set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]}
        {$pdf startPage}
    }}
    {title "page::context keys" type table content {
        {left        {dict get $ctx left   ;# left margin}    0}
        {top         {dict get $ctx top    ;# top margin}     0}
        {bottom      {dict get $ctx bottom ;# bottom margin}  0}
        {text_w      {dict get $ctx text_w ;# usable width}   0}
        {text_h      {dict get $ctx text_h ;# usable height}  0}
        {page_w      {dict get $ctx page_w}                   0}
        {page_h      {dict get $ctx page_h}                   0}
        {SY          {dict get $ctx SY  ;# orient y-factor}   0}
    }}
    {title "fonts" type table content {
        {init        {pdf4tcllib::fonts::init}                1}
        {setFont     {pdf4tcllib::fonts::setFont $pdf 12}     1}
        {{setFont style} {fonts::setFont $pdf 12 Helvetica bold} 1}
        {fontSans    {pdf4tcllib::fonts::fontSans}             1}
        {fontSansBold {pdf4tcllib::fonts::fontSansBold}       1}
        {fontMono    {pdf4tcllib::fonts::fontMono}             1}
        {hasTtf      {pdf4tcllib::fonts::hasTtf}              1}
        {widthFactor {pdf4tcllib::fonts::widthFactor $fname}  1}
    }}
    {title "page helpers" type table content {
        {header      {pdf4tcllib::page::header $pdf $ctx "Title"} 1}
        {footer      {pdf4tcllib::page::footer $pdf $ctx "p" $n}  1}
        {number      {pdf4tcllib::page::number $pdf $ctx $n}      1}
        {centerText  {pdf4tcllib::page::centerText $pdf $ctx $t $y} 1}
        {debugGrid   {pdf4tcllib::page::debugGrid $pdf $ctx}      1}
        {lineheight  {pdf4tcllib::page::lineheight $fs}           1}
        {_advance    {pdf4tcllib::page::_advance $ctx yVar $step} 1}
    }}
    {title "text" type table content {
        {width       {pdf4tcllib::text::width $t $fs $fn}         1}
        {wrap        {pdf4tcllib::text::wrap $line $maxW $fs $fn} 1}
        {truncate    {pdf4tcllib::text::truncate $t $w $fs $fn}   1}
        {expandTabs  {pdf4tcllib::text::expandTabs $line 4}       1}
        {detectFont  {pdf4tcllib::text::detectFont $line}         1}
        {writeParagraph {text::writeParagraph $pdf $t $x $y $w}  1}
    }}
    {title "unicode" type table content {
        {sanitize    {pdf4tcllib::unicode::sanitize $line}         1}
        {safeText    {pdf4tcllib::unicode::safeText $pdf $t -x -y} 1}
        {readFile    {pdf4tcllib::unicode::readFile $path}         1}
        {preprocessBytes {unicode::preprocessBytes $data}         1}
    }}
    {title "table" type table content {
        {simpleTable {pdf4tcllib::table::simpleTable $pdf $x $y $colW $rows} 1}
        {render      {table::render $pdf $data $x yVar $maxW ...}            1}
        {header      {list "Col1" "Col2"  ;# first row = header}             0}
        {aligns      {{left right center}  ;# per column}                    0}
        {rows        {{row1col1 row1col2} {row2col1 ...}}                    0}
    }}
    {title "drawing" type table content {
        {roundedRect {drawing::roundedRect $pdf $x $y $w $h $r}  1}
        {polygon     {drawing::polygon $pdf $cx $cy $r $sides}   1}
        {star        {drawing::star $pdf $cx $cy $r ?points?}    1}
        {{gradient v} {drawing::gradient_v $pdf $x $y $w $h $c1 $c2} 1}
        {{gradient h} {drawing::gradient_h $pdf $x $y $w $h $c1 $c2} 1}
        {textRotated {drawing::textRotated $pdf $t $x $y $angle $fs} 1}
        {frame       {drawing::frame $pdf $x $y $w $h}           1}
        {separator   {drawing::separator $pdf $x $y $w}          1}
    }}
    {title "form layout" type table content {
        {configure   {pdf4tcllib::form::configure -labelW 90 -fieldH 16} 1}
        {section     {form::section $pdf $ctx yVar "Titel"}       1}
        {labelField  {form::labelField $pdf $ctx yVar "Name" text} 1}
        {row         {form::row $pdf $ctx yVar {{Name text} {Qty int}}} 1}
        {separator   {form::separator $pdf $ctx yVar}             1}
        {orderTable  {form::orderTable $pdf $ctx yVar $hdrs $cols $rows} 1}
        {sumLine     {form::sumLine $pdf $ctx yVar $cols "Total" $val} 1}
    }}
}
