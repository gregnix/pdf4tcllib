title    "mdstack 0.3.3 -- Cheat Sheet"
subtitle "mdparser, mdviewer, mdpdf, mdhtml, mdtheme, mdoutline"
sections {
    {title "setup" type code content {
        {tcl::tm::path add /path/to/vendors/tm}
        {package require mdstack 0.3.3}
        {}
        {# Einzelne Module:}
        {package require mdparser}
        {package require mdviewer}
        {package require mdpdf}
    }}
    {title "mdparser" type table content {
        {parse       {mdparser::parse $mdtext}                      1}
        {parseFile   {mdparser::parseFile $path}                    1}
        {tokens      {returns token list: {type content meta}}      0}
        {types       {h1 h2 h3 para code ul ol blockquote hr}       0}
        {inline      {bold italic code link image}                  0}
    }}
    {title "mdviewer" type table content {
        {new         {mdviewer::new .viewer -width 600}             1}
        {render      {.viewer render $mdtext}                       1}
        {renderFile  {.viewer renderFile $path}                     1}
        {configure   {.viewer configure -theme dark}                1}
        {scroll      {.viewer yview moveto 0.5}                     1}
        {theme       {mdviewer::setTheme default|dark|print}        1}
    }}
    {title "mdpdf" type table content {
        {render      {mdpdf::render $pdf $mdtext $ctx}              1}
        {renderFile  {mdpdf::renderFile $pdf $path $ctx}            1}
        {setTheme    {mdpdf::setTheme $themeDict}                   1}
        {ctx         {page::context a4 -margin 20 -orient true}     1}
        {fonts       {fonts::init first  ;# TTF for Unicode}        0}
        {multipage   {respects ctx top/bottom for page breaks}      0}
    }}
    {title "mdhtml" type table content {
        {render      {mdhtml::render $mdtext}                       1}
        {renderFile  {mdhtml::renderFile $path}                     1}
        {template    {mdhtml::render $md -template $html}           1}
        {standalone  {mdhtml::render $md -standalone 1}             1}
    }}
    {title "mdtheme" type table content {
        {get         {mdtheme::get default}                         1}
        {set         {mdtheme::set myTheme $dict}                   1}
        {keys        {h1 h2 h3 h4 para code ul ol blockquote hr}    0}
        {{font keys}  {font size color bold italic}  0}
        {spacing     {spaceBefore spaceAfter lineSpacing}           0}
        {colors      {foreground background codeBackground}         0}
    }}
    {title "mdoutline" type table content {
        {extract     {mdoutline::extract $mdtext}                   1}
        {returns     {list of {level title anchor}}                 0}
        {toTOC       {mdoutline::toTOC $outline}                    1}
        {bookmarks   {mdoutline::addBookmarks $pdf $outline}        1}
    }}
    {title "mdstacknoteskit" type table content {
        {render      {mdstacknoteskit::render $pdf $notes $ctx}     1}
        {layout      {two-column notes layout}                      0}
        {pagebreak   {--- (HR) inserts page break in notes}         0}
    }}
    {title "mdhelp4 integration" type table content {
        {consumer    {mdhelp4 is primary mdstack consumer}          0}
        {tests       {179 tests, fully English (code+UI)}           0}
        {version     {package require mdstack 0.3.3}                1}
        {vendors     {vendors/tm/mdstack-0.3.3.tm}                  0}
    }}
}
