title    "pdf4tcl 0.9.4.25 -- Cheat Sheet"
    subtitle "github.com/gregnix/pdf4tcl"
    sections {
        {title "Setup" type code content {
            {lappend auto_path /pfad/zu/pdf4tcl}
            {package require pdf4tcl 0.9.4.25}
            {set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]}
            {$pdf startPage}
            {# ... zeichnen ...}
            {$pdf endPage}
            {$pdf write -file out.pdf  ;# oder: -chan $ch}
            {$pdf destroy}
        }}
        {title "Text" type table content {
            {setFont        {$pdf setFont 12 Helvetica}                   1}
            {text           {$pdf text "Hallo" -x 50 -y 100}             1}
            {drawTextBox    {$pdf drawTextBox x y w h txt -align left}    1}
            {getStringWidth {getStringWidth str -font Helvetica -size 12} 1}
            {Fonts          {Helvetica Times-Roman Courier (+ Bold/Oblique)} 0}
        }}
        {title "Farben" type table content {
            {setFillColor   {$pdf setFillColor r g b  ;# 0.0-1.0}  1}
            {setStrokeColor {$pdf setStrokeColor r g b}             1}
            {setAlpha       {$pdf setAlpha 0.5}                     1}
        }}
        {title "Formen" type table content {
            {line        {$pdf line x1 y1 x2 y2}                        1}
            {rectangle   {$pdf rectangle x y w h -filled 1}             1}
            {roundedRect {$pdf roundedRect x y w h -radius 8 -filled 1} 1}
            {oval        {$pdf oval x y w h}                            1}
            {circle      {$pdf circle x y r}                            1}
            {polygon     {$pdf polygon x1 y1 x2 y2 ...}                1}
            {arc         {$pdf arc x y w h start extent}               1}
        }}
        {title "Linien-Stil" type table content {
            {setLineWidth {$pdf setLineWidth 2}                        1}
            {setLineDash  {$pdf setLineDash 6 3  ;# on off}           1}
            {setLineStyle {$pdf setLineStyle solid|dash|dot|dashdot}  1}
        }}
        {title "Seiten + Koordinaten" type table content {
            {startPage       {startPage ?-paper a3? ?-landscape 1?}   1}
            {getDrawableArea {lassign [$pdf getDrawableArea] w h}      1}
            {getPageSize     {lassign [$pdf getPageSize] w h}          1}
            {inPage          {$pdf inPage  ;# 1/0}                    1}
            {currentPage     {$pdf currentPage  ;# 1-basiert}         1}
            {orient          {-orient true: y=0 oben, nach unten}     0}
        }}
        {title "Papierformate (0.9.4.25)" type table content {
            {A-Serie  {a0..a10, 2a0, 4a0}          0}
            {B-Serie  {b0..b10}                    0}
            {C-Serie  {c0..c10  (Umschlaege)}      0}
            {US       {letter legal ledger 11x17}  0}
            {Abfragen {pdf4tcl::getPaperSize a4}   1}
        }}
        {title "Bilder" type table content {
            {addImage {set id [$pdf addImage file.jpg]}    1}
            {putImage {$pdf putImage $id x y -width 100}  1}
        }}
        {title "Transformation" type table content {
            {gsave     {$pdf gsave}                         1}
            {grestore  {$pdf grestore}                      1}
            {rotate    {$pdf rotate 90 -x cx -y cy}        1}
            {translate {$pdf translate dx dy}              1}
            {scale     {$pdf scale sx sy}                  1}
            {transform {$pdf transform a b c d e f}        1}
            {Hinweis   {gsave/grestore um Zustand sichern} 0}
        }}
        {title "Font Metrics" type table content {
            {getStringWidth {getStringWidth str -font H. -size 12}  1}
            {getFontMetric  {$pdf getFontMetric ascender}           1}
            {getLineHeight  {$pdf getLineHeight}                    1}
            {Metriken       {ascender descender bboxb bboxt}        0}
        }}
        {title "Ausgabe (write)" type table content {
            {-file  {$pdf write -file output.pdf}           1}
            {-chan  {$pdf write -chan $ch  ;# NEU 0.9.4.25} 1}
            {stdout {$pdf write  ;# nach stdout}            1}
            {get    {set d [$pdf get]  ;# als String}       1}
        }}
        {title "Gradienten" type table content {
            {linearGradient {$pdf linearGradient x1 y1 x2 y2 stops}    1}
            {radialGradient {$pdf radialGradient cx cy r stops}         1}
            {stops          {{{0 "1 0 0"} {1 "0 0 1"}}  ;# r g b}      1}
            {setBlendMode   {$pdf setBlendMode Normal|Multiply|...}     1}
        }}
        {title "Text-Optionen" type table content {
            {newLine        {$pdf newLine  ;# y += lineSpacing}     1}
            {moveTextPos    {$pdf moveTextPosition dx dy}           1}
            {setTextPos     {$pdf setTextPosition x y}             1}
            {getTextPos     {$pdf getTextPosition  -> x y}         1}
            {setLineSpacing {$pdf setLineSpacing 1.2}              1}
            {drawTextBox    {-align left|right|center|justify}     0}
            {""             {-linesvar N  -newyvar yvar}           0}
        }}
        {title "Lesezeichen + Links" type table content {
            {bookmarkAdd  {$pdf bookmarkAdd -title "Kapitel" -level 1} 1}
            {hyperlinkAdd {$pdf hyperlinkAdd x y w h url}             1}
            {pageLabel    {$pdf pageLabel -prefix "A-" -start 1}      1}
        }}
        {title "Layer (OCG)" type table content {
            {addLayer   {set id [$pdf addLayer "Ebene 1"]}  1}
            {beginLayer {$pdf beginLayer $id}               1}
            {endLayer   {$pdf endLayer}                     1}
            {Hinweis    {-pdfa 2b+ erlaubt Layer}           0}
        }}
        {title "Encryption" type table content {
            {-encryption {pdf4tcl::new ... -encryption aes256}           1}
            {-password   {-userpwd "user" -ownerpwd "owner"}             1}
            {AES-128     {V=4/R=4 -- ab 0.9.4.11}                        0}
            {AES-256     {V=5/R=6 -- ab 0.9.4.16}                        0}
            {{Kein PDF/A}  {Encryption + PDF/A schliessen sich aus}  0}
        }}
        {title "Metadata + PDF/A" type table content {
            {metadata    {$pdf metadata -author "Name" -title "..."}     1}
            {-pdfa       {pdf4tcl::new ... -pdfa 1b|2b|3b}              1}
            {addEmbedded {$pdf addEmbeddedFile file.xml "factur-x.xml"}  1}
            {viewerPref  {$pdf viewerPreferences -fitwindow 1}           1}
        }}
    }
