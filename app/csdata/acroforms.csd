title    "AcroForm (pdf4tcl 0.9.4.x) -- Cheat Sheet"
subtitle "addForm, Ff-Flags, AP-Streams, FDF/XFDF Export"
sections {
    {title "addForm types" type table content {
        {text        {addForm text x y w h -name id -value "v"}     1}
        {password    {addForm password x y w h -name id}            1}
        {checkbutton {addForm checkbutton x y w h -name id}         1}
        {combobox    {addForm combobox x y w h -values {a b c}}     1}
        {listbox     {addForm listbox x y w h -values {a b c}}      1}
        {radiobutton {addForm radiobutton x y w h -group g -value v} 1}
        {pushbutton  {addForm pushbutton x y w h -label "OK"}       1}
        {signature   {addForm signature x y w h -name sig}          1}
    }}
    {title "addForm options" type table content {
        {-name       {field name (unique ID)}                       0}
        {-value      {default value}                                0}
        {-label      {visible label (pushbutton)}                   0}
        {-values     {list of options (combo/listbox)}              0}
        {-group      {radio group name}                             0}
        {-required   {1 = field required}                           0}
        {-readonly   {1 = read only}                                0}
        {-multiline  {1 = multiline text field}                     0}
        {-tabindex   {tab order index}                              0}
        {-tooltip    {tooltip text}                                 0}
    }}
    {title "Ff flag constants" type table content {
        {READONLY    {1}                                            0}
        {REQUIRED    {2}                                            0}
        {NOEXPORT    {4}                                            0}
        {MULTILINE   {4096}                                         0}
        {PASSWORD    {8192}                                         0}
        {NOTOGGLEOFF {16384  ;# radio: one always selected}        0}
        {RADIO       {32768}                                        0}
        {PUSHBUTTON  {65536}                                        0}
        {COMBO       {131072}                                       0}
        {EDIT        {262144  ;# editable combo}                   0}
    }}
    {title "AP stream helpers" type table content {
        {{_BuildTextAP}    {internal: text field appearance}        0}
        {{_BuildCheckAP}   {internal: checkbutton on/off}           0}
        {{_BuildComboAP}   {internal: combobox appearance}          0}
        {{_BuildListAP}    {internal: listbox appearance}           0}
        {{_BuildRadioAP}   {internal: radiobutton appearance}       0}
        {{_BuildButtonAP}  {internal: pushbutton appearance}        0}
        {NeedAppearances  {NEVER set -- breaks digital signatures}  0}
        {QuoteString      {QuoteString $str  ;# PDF string escape}  1}
    }}
    {title "encryption + forms" type table content {
        {strings     {/T /DA /V strings are encrypted}              0}
        {bug         {AcroForm string encryption bug: workaround}   0}
        {workaround  {use forms without encryption}                 0}
        {AES-128     {V=4/R=4: strings encrypted in 0.9.4.11+}     0}
        {AES-256     {V=5/R=6: strings encrypted in 0.9.4.16+}     0}
    }}
    {title "FDF / XFDF export" type table content {
        {exportForms {pdf4tcl::exportForms $pdf fdf out.fdf}        1}
        {xfdf        {pdf4tcl::exportForms $pdf xfdf out.xfdf}      1}
        {getForms    {pdf4tcl::getForms infile.pdf}                  1}
        {{FDF format}  {ISO 32000 SS12.7.7}  0}
        {{XFDF format}  {ISO 32000 SS12.7.8, human-readable XML}  0}
    }}
    {title "radio group pattern" type code content {
        {# Radio buttons share -group name}
        {$pdf addForm radiobutton $x $y 12 12 -group size -value small}
        {$pdf addForm radiobutton $x $y2 12 12 -group size -value large}
        {# Group finalized at write time}
    }}
    {title "rules" type table content {
        {{unique name}  {each field needs a unique -name}  0}
        {{no NeedApp}  {NeedAppearances must never be set}  0}
        {orient       {coordinates in document units (-orient true)} 0}
        {fonts        {DA uses /Helvetica or embedded font}          0}
        {PDF/A        {forms allowed in PDF/A-1b+}                   0}
        {signature    {placeholder only -- no cert signing}          0}
    }}
}
