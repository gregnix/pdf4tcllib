title    "Canvas Export -- Cheat Sheet (pdf4tcl 0.9.4.25)"
    subtitle "tk::canvas / tkpath (PathCanvas) / tko::path"
    sections {
        {title "Grundaufruf" type code content {
            {update  ;# Canvas muss gerendert sein}
            {set bb [$canvas bbox all]}
            {$pdf canvas $canvas -bbox $bb -x lx -y ly -width w -height h}
        }}
        {title "Optionen: canvas" type table content {
            {-bbox          {Bereich (noetig bei tkpath/tko)}    1}
            {{-x / -y}  {Position auf der PDF-Seite}  1}
            {-width/-height {Groesse auf der Seite}              1}
            {-sticky        {nw (default), ns, ew, nsew}         1}
            {-bg            {Hintergrund malen (default: 0)}     1}
            {-fontmap       {Tk-Fontname -> PDF-Fontname}        1}
            {Return         {bbox in PDF-Koordinaten}            1}
        }}
        {title "tk::canvas  (class: Canvas)" type table content {
            {Items    {rect oval line polygon arc text image window}  0}
            {-matrix  {nicht unterstuetzt}                           0}
            {window   {Img + on-screen; Fallback: schwarzes Rect}    0}
            {Dispatch {CanvasDoItem (cls=1)}                         0}
        }}
        {title "tkpath  (class: PathCanvas)" type table content {
            {Items      {prect circle ellipse pline polyline ppolygon path group pimage ptext} 0}
            {-matrix    {VERSCHACHTELT: {{a b} {c d} {tx ty}}}  1}
            {{-stroke ""}  {leer ok (kein Stroke)}  1}
            {gradient   {$w gradient create linear/radial}      1}
            {Dispatch   {CanvasDoTkpathItem (cls=2)}            0}
        }}
        {title "tko::path  (class: tko::path)" type table content {
            {Items      {rect circle ellipse line polyline polygon path group text image window} 0}
            {-matrix    {FLACH: {a b c d tx ty}  (6 Zahlen)}    1}
            {{-stroke ""}  {CRASH! Immer Farbe angeben}  1}
            {window     {still uebersprungen (BUG-C1 Fix 0.9.4.24)} 0}
            {Dispatch   {CanvasDoTkoPathItem (cls=3)}           0}
        }}
        {title "Vergleich tkpath vs tko::path" type table content {
            {Item-Prefix {tkpath: p-Prefix  |  tko: kein Prefix}   0}
            {matrix      {tkpath: verschachtelt  |  tko: flach}    0}
            {{stroke leer}  {tkpath: ok  |  tko: CRASH}  0}
            {Gradient    {tkpath: ja  |  tko: nicht getestet}      0}
            {window      {tkpath: ---  |  tko: uebersprungen}      0}
        }}
        {title "Wichtige Regeln" type table content {
            {update      {update/idletasks vor Export}                   0}
            {-bbox       {Immer -bbox [$w bbox all] bei tkpath/tko}      0}
            {orient      {-orient true + page::context synchron}         0}
            {{text -y}  {= Baseline (nicht Oberkante)}  0}
            {splinesteps {ignoriert -- exakte Bezier-Kurven}             0}
        }}
        {title "tkpath: Gradienten" type code content {
            {set g [$w gradient create linear -stops {{0 red} {1 blue}}]}
            {$w create prect 10 10 200 100 -fill $g}
            {set r [$w gradient create radial -stops {{0 white} {1 "#0055aa"}}]}
            {$w create circle 100 100 -r 50 -fill $r}
        }}
        {title "Canvas Text-Optionen" type table content {
            {tk::canvas   {-text -font -anchor -fill -justify}          0}
            {{tkpath ptext}  {-text -fontfamily -fontsize -fontweight}  0}
            {""           {-fontslant -textanchor -fill}                0}
            {tko::path    {-text -fontfamily -fontsize -fontweight}     0}
            {""           {-fontslant -textanchor -fill}                0}
            {textanchor   {start | middle | end}                        0}
        }}
        {title "Typisches Export-Pattern" type code content {
            {wm withdraw .}
            {canvas .c -width 400 -height 300}
            {pack .c}
            {# Items zeichnen...}
            {update idletasks}
            {set pdf [pdf4tcl::new %AUTO% -paper a4]}
            {$pdf startPage}
            {$pdf canvas .c -bbox [.c bbox all] -x 50 -y 50}
            {$pdf endPage}
            {$pdf write -file out.pdf  ;  $pdf destroy}
        }}
        {title "Canvas Bild-Export" type table content {
            {addImage {set img [$pdf addImage [$c image create photo ...]]} 1}
            {-image   {.c create image x y -image $photo}                  1}
            {pimage   {.c create pimage x1 y1 x2 y2 -image $photo}        1}
            {Tipp     {update vor bbox: sonst falsche Masse}               0}
        }}
    }
