#!/usr/bin/env tclsh
# Erzeugt 4 Cheat-Sheet PDFs fuer pdf4tcl 0.9.4.25
# Verwendet cheatsheet-0.1.tm -- Trennung von Daten und Layout.
#
# Ausgabe: out/pdf4tcl-cheat-sheet.pdf
#          out/pdf-cheat-sheet.pdf
#          out/canvas-cheat-sheet.pdf
#          out/pdf-internals-cheat-sheet.pdf

set scriptDir [file dirname [file normalize [info script]]]
lappend auto_path $scriptDir

# cheatsheet-0.1.tm laden (vendors/tm relativ zum Demo-Verzeichnis)
set csPath [file normalize [file join $scriptDir ../../vendors/tm]]
if {[file isdir $csPath]} { tcl::tm::path add $csPath }

package require pdf4tcl
package require cheatsheet 0.1

set outDir [file join $scriptDir out]
file mkdir $outDir

# ============================================================
# Sheet 1: pdf4tcl-cheat-sheet.pdf
# ============================================================
set sheet1 {
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
}

# ============================================================
# Sheet 2: pdf-cheat-sheet.pdf
# ============================================================
set sheet2 {
    title    "PDF Grundlagen -- Cheat Sheet"
    subtitle "Koordinaten, Einheiten, Papierformate, PDF-Struktur"
    sections {
        {title "Einheiten" type table content {
            {{1 pt (Point)}  {= 1/72 Inch = 0.353 mm}  0}
            {{1 mm}  {= 2.835 pt}  0}
            {{1 cm}  {= 28.35 pt}  0}
            {{1 Inch}  {= 72 pt}  0}
            {Umrechnung   {mm -> pt:  val * 72.0 / 25.4}  1}
        }}
        {title "Papiergroessen (in pt)" type table content {
            {a4     {595 x 842   |  a3: 842 x 1191}    0}
            {a5     {420 x 595   |  a6: 298 x 420}     0}
            {b4     {709 x 1001  |  b5: 499 x 709}     0}
            {c4     {649 x 918   |  c5: 459 x 649}     0}
            {letter {612 x 792   |  legal: 612 x 1008} 0}
            {2a0    {3370 x 4768 |  4a0: 4768 x 6741}  0}
        }}
        {title "Koordinatensystem" type table content {
            {{orient true}  {(0,0) oben-links, y nach unten (Tk)}  0}
            {{orient false}  {(0,0) unten-links, y nach oben (PDF)}  0}
            {Empfehlung   {-orient true immer explizit setzen}     0}
            {Baseline     {text -y = Baseline, nicht Oberkante}    0}
            {""           {Ascender ~ 0.75 * fontSize}             0}
        }}
        {title "PDF-Operatoren" type table content {
            {{m / l / c}  {moveto lineto curveto}  1}
            {{S / s}  {stroke offen / geschlossen}  1}
            {{f / B}  {fill / fill+stroke}  1}
            {{q / Q}  {gsave / grestore}  1}
            {cm        {concat matrix (Transform)}           1}
            {{BT / ET}  {Textblock begin / end}  1}
            {Tm        {Textmatrix setzen}                   1}
            {{Tj / TJ}  {Text ausgeben}  1}
            {{rg / RG}  {fill / stroke color (RGB)}  1}
            {{w / d}  {Linienbreite / Dash-Pattern}  1}
            {{J / j}  {Linienende / Verbindung}  1}
        }}
        {title "PDF-Struktur" type table content {
            {Header    {%PDF-x.x  (erste Zeile)}                   0}
            {Objekte   {N 0 obj ... endobj}                        0}
            {Streams   {<< /Length N >> stream...endstream}        0}
            {XRef      {xref-Tabelle oder XRef-Stream}             0}
            {Trailer   {trailer << /Root /Info /Size >>}           0}
            {startxref {Offset der XRef-Tabelle}                   0}
            {EOF       {%%EOF (letzte Zeile)}                      0}
        }}
        {title "PDF/A (pdf4tcl)" type table content {
            {PDF/A-1b    {-pdfa 1b: Basis, keine Transparenz}         0}
            {PDF/A-2b    {-pdfa 2b: + Transparenz, Layer}             0}
            {PDF/A-3b    {-pdfa 3b: + Embedded Files (ZUGFeRD)}       0}
            {Validierung {veraPDF: https://verapdf.org}               0}
        }}
        {title "Farbmodelle" type table content {
            {DeviceRGB  {rg/RG: r g b  (0.0-1.0)}  1}
            {DeviceGray {g/G: gray (0.0-1.0)}       1}
            {DeviceCMYK {k/K: c m y k}              1}
            {Schwarz    {0 0 0 rg  oder  0 g}       1}
            {Weiss      {1 1 1 rg  oder  1 g}       1}
        }}
        {title "PDF Debugging" type table content {
            {{qpdf --check}  {Struktur pruefen}  1}
            {{qpdf --json}  {Alle Objekte als JSON}  1}
            {pdfinfo      {Metadaten, Seitenzahl, Version}    1}
            {pdftotext    {Text-Extraktion testen}            1}
            {veraPDF      {PDF/A-Validierung}                 1}
            {Ghostscript  {gs -dNOPAUSE -sDEVICE=nullpage}   1}
        }}
        {title "Haeufige PDF-Fehler" type table content {
            {off-by-one    {/Length falsch -> korrupt}              0}
            {{fehlendes EOL}  {\r\n vor endstream noetig (PDF/A)}  0}
            {XRef-Offset   {startxref falsch -> nicht lesbar}      0}
            {{Font missing}  {/BaseFont nicht eingebettet}  0}
            {Encoding      {WinAnsi vs UTF-8 Mischung}             0}
            {Transparenz   {setAlpha < 1.0 verboten in PDF/A-1b}  0}
        }}
        {title "Koordinaten-Formeln" type table content {
            {{mm -> pt}  {pt = mm * 72.0 / 25.4}  1}
            {{pt -> mm}  {mm = pt * 25.4 / 72.0}  1}
            {Zentrierung {x = (pageW - textW) / 2.0}            1}
            {Texthoehe   {y += fontSize * lineSpacing}           1}
            {Druckrand   {lassign [$pdf getDrawableArea] w h}     1}
            {Box-Mitte   {cx = x + w/2.0  cy = y + h/2.0}       1}
        }}
        {title "Externe Tools (Linux)" type table content {
            {pdftocairo {pdftocairo -png -r 150 in.pdf out}           1}
            {pdftk      {pdftk in.pdf burst / cat / compress}         1}
            {{qpdf merge}  {qpdf --empty --pages a.pdf b.pdf -- out.pdf}  1}
            {{gs pdf/a}  {gs -dPDFA=2 -dBATCH ... in.pdf}  1}
            {ocrmypdf   {ocrmypdf -l deu in.pdf out.pdf}              1}
        }}
    }
}

# ============================================================
# Sheet 3: canvas-cheat-sheet.pdf
# ============================================================
set sheet3 {
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
}

# ============================================================
# Sheet 4: pdf-internals-cheat-sheet.pdf
# ============================================================
set sheet4 {
    title    "PDF Internals -- Cheat Sheet"
    subtitle "Objektstruktur, Font/CMap, XRef, Streams, Encryption, XMP"
    sections {
        {title "PDF Objektstruktur" type code content {
            {%PDF-1.7}
            {1 0 obj  << /Type /Catalog /Pages 2 0 R >>  endobj}
            {2 0 obj  << /Type /Pages /Kids [3 0 R] /Count 1 >>  endobj}
            {3 0 obj  << /Type /Page /Parent 2 0 R ...>>  endobj}
            {4 0 obj  << /Length 44 >>}
            {stream}
            {BT /F1 12 Tf 50 800 Td (Hallo) Tj ET}
            {endstream  endobj}
            {xref  trailer  startxref  %%EOF}
        }}
        {title "Stream Filter" type table content {
            {FlateDecode {zlib/deflate Kompression (Standard)}  0}
            {DCTDecode   {JPEG Bilder}                          0}
            {CCITTFax    {Fax/TIFF 1-bit}                      0}
            {JPXDecode   {JPEG2000 (PDF/A-2b+)}                0}
            {ASCII85     {ASCII-Kodierung}                      0}
            {Length      {immer exakt -- off by one -> kaputt} 0}
            {Newline     {\r\n vor endstream (PDF/A-Pflicht)}  0}
        }}
        {title "Font Struktur" type table content {
            {Type1     {Standard 14: Helvetica Times Courier Symbol}  0}
            {TrueType  {/Type /Font /Subtype /TrueType}               0}
            {CIDFont   {fuer Unicode/CJK -- Type0 Wrapper}           0}
            {Encoding  {WinAnsiEncoding / MacRomanEncoding}           0}
            {ToUnicode {CMap Stream -- Pflicht fuer Suche/Copy}       0}
            {Widths    {Array der Zeichenbreiten (1/1000 em)}         0}
        }}
        {title "XRef Tabelle vs XRef Stream" type table content {
            {Tabelle   {xref\n 0 N\n 0000000000 65535 f\n}           1}
            {Stream    {<</Type/XRef /W [1 4 2] /Index ...>>}        1}
            {PDF/A-2b+ {XRef Stream Pflicht (pdf4tcl ab 0.9.4.22)}   0}
            {Offset    {startxref = Byte-Offset XRef vom Dateistart} 0}
        }}
        {title "Encryption (pdf4tcl)" type table content {
            {RC4-128    {V=3/R=3 -- veraltet}                         0}
            {AES-128    {V=4/R=4 -- pdf4tcl 0.9.4.11+}               0}
            {AES-256    {V=5/R=6 -- pdf4tcl 0.9.4.16+}               0}
            {Schluessel {UserPassword / OwnerPassword}                0}
            {Strings    {/T /DA /V in Formularen werden verschl.}     0}
            {{Kein PDF/A}  {Encryption + PDF/A schliessen sich aus}  0}
        }}
        {title "XMP Metadata (PDF/A Pflicht)" type table content {
            {Stream     {/Type /Metadata /Subtype /XML}               0}
            {Namespaces {dc: xmp: pdf: pdfaid: xmpMM:}               0}
            {pdfaid     {/pdfaid:part '1'|'2'|'3' + conformance 'B'} 0}
            {Producer   {xmp:CreatorTool + pdf:Producer}              0}
            {Dates      {xmp:CreateDate / xmp:ModifyDate (ISO 8601)}  0}
        }}
        {title "PDF/A Pflichtfelder" type table content {
            {OutputIntent {sRGB ICC-Profil eingebettet}           0}
            {XMP          {pdfaid:part + pdfaid:conformance}      0}
            {ToUnicode    {fuer alle verwendeten Fonts}           0}
            {{Kein ExtGS}  {keine Transparenz bei PDF/A-1b}  0}
            {{Kein JS}  {kein JavaScript}  0}
            {Validierung  {veraPDF: https://verapdf.org}          0}
        }}
        {title "Annotation Typen (pdf4tcl 0.9.4.23+)" type table content {
            {Note      {addAnnotNote x y w h text}       1}
            {FreeText  {addAnnotFreeText x y w h text}   1}
            {Highlight {addAnnotHighlight x y w h}       1}
            {StrikeOut {addAnnotStrikeOut x y w h}       1}
            {Underline {addAnnotUnderline x y w h}       1}
            {Line      {addAnnotLine x1 y1 x2 y2}       1}
            {Stamp     {addAnnotStamp x y w h text}      1}
        }}
        {title "AcroForm (Formularfelder)" type table content {
            {text        {addForm text x y w h -name id}             1}
            {checkbutton {addForm checkbutton x y w h}               1}
            {radiobutton {addForm radiobutton x y w h -group g}      1}
            {combobox    {addForm combobox x y w h -values {a b c}}  1}
            {listbox     {addForm listbox x y w h -values {a b}}     1}
            {pushbutton  {addForm pushbutton x y w h -label OK}      1}
            {Export      {pdf4tcl::exportForms $pdf FDF out.fdf}     1}
        }}
    }
}

# ============================================================
# PDFs erzeugen
# ============================================================
cheatsheet::fromDict [file join $outDir pdf4tcl-cheat-sheet.pdf]       $sheet1
puts "pdf4tcl-cheat-sheet.pdf"

cheatsheet::fromDict [file join $outDir pdf-cheat-sheet.pdf]           $sheet2
puts "pdf-cheat-sheet.pdf"

cheatsheet::fromDict [file join $outDir canvas-cheat-sheet.pdf]        $sheet3
puts "canvas-cheat-sheet.pdf"

cheatsheet::fromDict [file join $outDir pdf-internals-cheat-sheet.pdf] $sheet4
puts "pdf-internals-cheat-sheet.pdf"

puts "\nAlle Cheat Sheets in: $outDir"
