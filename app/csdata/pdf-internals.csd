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
