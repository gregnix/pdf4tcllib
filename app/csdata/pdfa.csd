title    "PDF/A (pdf4tcl 0.9.4.x) -- Cheat Sheet"
subtitle "PDF/A-1b, 2b, 3b -- Konformitaet, Validierung, Checkliste"
sections {
    {title "PDF/A aktivieren" type code content {
        {set pdf [::pdf4tcl::new %AUTO%     }
        {    -paper a4                      }
        {    -orient true                   }
        {    -pdfa 1b]   ;# 1b | 2b | 3b   }
        {}
        {# ICC-Profil explizit angeben:}
        {set pdf [::pdf4tcl::new %AUTO%     }
        {    -pdfa 2b                       }
        {    -pdfa-icc /usr/share/color/...]}
    }}
    {title "PDF/A Varianten" type table content {
        {PDF/A-1b    {ISO 19005-1, -pdfa 1b}                        0}
        {PDF/A-2b    {ISO 19005-2, -pdfa 2b  + Transparenz, Layer}  0}
        {PDF/A-3b    {ISO 19005-3, -pdfa 3b  + EmbeddedFiles}       0}
        {veraPDF     {144/144 direkt (ohne Ghostscript) ab 0.9.4.22} 0}
    }}
    {title "Pflichtfelder" type table content {
        {OutputIntent  {sRGB ICC-Profil eingebettet (-pdfa-icc)}     0}
        {XMP           {/Type /Metadata /Subtype /XML}               0}
        {pdfaid:part   {'1' | '2' | '3'}                            0}
        {pdfaid:conf.  {'B' (Basic)}                                 0}
        {ToUnicode     {CMap fuer alle verwendeten Fonts}            0}
        {{XRef Stream}  {Pflicht bei PDF/A-2b+ (ab 0.9.4.22)}  0}
        {%PDF-1.7      {Pflicht bei PDF/A-2b+ (ab 0.9.4.22)}        0}
    }}
    {title "Verboten in PDF/A-1b" type table content {
        {Transparenz   {setAlpha < 1.0 verboten}                     0}
        {Encryption    {Encryption + PDF/A schliessen sich aus}      0}
        {JavaScript    {kein JS erlaubt}                             0}
        {EmbeddedFiles {keine eingebetteten Dateien (nur PDF/A-3b)}  0}
        {ExtGState     {/ca /CA = 1.0 in ExtGState erlaubt}          0}
    }}
    {title "PDF/A-2b Zusatz" type table content {
        {Transparenz   {setAlpha erlaubt (ExtGState ca/CA)}          0}
        {Layer/OCG     {addLayer/beginLayer/endLayer erlaubt}        0}
        {OCG/AS        {/AS-Array im /D-Dict (SS6.2.10)}             0}
        {JPEG2000      {JPXDecode Filter erlaubt}                    0}
        {{XRef Stream}  {Pflicht (nicht optional)}  0}
    }}
    {title "PDF/A-3b Zusatz" type table content {
        {EmbeddedFiles {addEmbeddedFile erlaubt}                     0}
        {AF-Array      {/AF-Array fuer eingebettete Dateien}         0}
        {ZUGFeRD       {addEmbeddedFile file.xml "factur-x.xml"}     1}
        {AFRelationship {Alternative|Data|Source|Supplement}         0}
    }}
    {title "Validierung" type table content {
        {veraPDF     {verapdf --flavour 1b in.pdf}                   1}
        {{GS convert}  {gs -dPDFA=2 -dBATCH -dNOPAUSE ...}  1}
        {{qpdf check}  {qpdf --check in.pdf}  1}
        {pdfinfo     {pdfinfo in.pdf | grep PDF}                    1}
        {embedded    {pdfinfo -meta in.pdf | grep pdfaid}           1}
    }}
    {title "Checkliste" type list content {
        "-pdfa 1b|2b|3b beim pdf4tcl::new"
        "Nur eingebettete Fonts (CIDFont oder Standard-14)"
        "Kein setAlpha < 1.0 bei PDF/A-1b"
        "sRGB ICC-Profil vorhanden (auto oder -pdfa-icc)"
        "ToUnicode CMap fuer alle Fonts"
        "Keine Encryption"
        "Kein JavaScript"
        "EmbeddedFiles nur bei PDF/A-3b"
        "veraPDF Validierung durchfuehren"
    }}
}
