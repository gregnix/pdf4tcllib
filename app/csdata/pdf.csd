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
