title    "Tk Layout & Widgets -- Cheat Sheet"
subtitle "grid, pack, place, ttk, bind, event"
sections {
    {title "grid" type table content {
        {grid        {grid $w -row 0 -column 1 -sticky nsew}   1}
        {columnspan  {grid $w -columnspan 2}                   1}
        {rowspan     {grid $w -rowspan 3}                      1}
        {padding     {grid $w -padx 4 -pady 4 -ipadx 2}       1}
        {weight      {grid columnconfigure . 0 -weight 1}      1}
        {minsize     {grid rowconfigure . 1 -minsize 20}       1}
        {remove      {grid remove $w  ;# hide, keeps config}   1}
        {forget      {grid forget $w  ;# remove + lose config} 1}
        {info        {grid info $w}                            1}
    }}
    {title "pack" type table content {
        {pack        {pack $w -side left -fill x -expand 1}    1}
        {side        {-side top|bottom|left|right}              0}
        {fill        {-fill none|x|y|both}                     0}
        {expand      {-expand 1  ;# claim extra space}         0}
        {anchor      {-anchor n|s|e|w|ne|...|center}           0}
        {padding     {-padx 4 -pady 4 -ipadx 2 -ipady 2}      0}
        {after       {pack $w -after $other}                   1}
        {before      {pack $w -before $other}                  1}
    }}
    {title "place" type table content {
        {absolute    {place $w -x 50 -y 100}                   1}
        {relative    {place $w -relx 0.5 -rely 0.5}            1}
        {anchor      {place $w -relx 0.5 -anchor center}       1}
        {size        {place $w -width 200 -height 100}         1}
        {relsize     {place $w -relwidth 1.0 -relheight 0.5}   1}
    }}
    {title "ttk widgets" type table content {
        {frame       {ttk::frame .f -padding 8}                1}
        {label       {ttk::label .l -text "Hi" -font {H 12}}  1}
        {button      {ttk::button .b -text "OK" -command cmd} 1}
        {entry       {ttk::entry .e -textvariable myvar}       1}
        {combobox    {ttk::combobox .c -values {a b c}}        1}
        {checkbutton {ttk::checkbutton .cb -variable v}        1}
        {radiobutton {ttk::radiobutton .rb -value x -var v}    1}
        {spinbox     {ttk::spinbox .s -from 0 -to 100}        1}
        {notebook    {ttk::notebook .nb}                       1}
        {treeview    {ttk::treeview .t -columns {A B}}         1}
        {scrollbar   {ttk::scrollbar .sb -command {.t yview}} 1}
        {separator   {ttk::separator .sep -orient horizontal} 1}
        {progressbar {ttk::progressbar .p -variable pct}      1}
    }}
    {title "bind / event" type table content {
        {{bind B-1}  {bind $w <Button-1> {handler %x %y}}  1}
        {{bind key}  {bind $w <Return> {submit}}  1}
        {{bind all}  {bind all <Escape> {exit}}  1}
        {unbind      {bind $w <Button-1> {}}                   1}
        {{event subs}  {% x %y %k %K %b %w %h %W %X %Y %s %A}  0}
        {virtual     {event generate $w <<MyEvent>>}           1}
        {after       {after 500 {callback}}                    1}
        {{after cancel}  {after cancel $id}  1}
        {update      {update idletasks}                        1}
    }}
    {title "wm / winfo" type table content {
        {title       {wm title . "My App"}                     1}
        {geometry    {wm geometry . 800x600+100+50}            1}
        {resizable   {wm resizable . 1 0  ;# x y}             1}
        {withdraw    {wm withdraw .}                           1}
        {deiconify   {wm deiconify .}                         1}
        {protocol    {wm protocol . WM_DELETE_WINDOW {exit}}  1}
        {{winfo width}  {winfo width $w}  1}
        {{winfo class}  {winfo class $w}  1}
        {{winfo exists}  {winfo exists $w}  1}
        {{winfo children}  {winfo children .}  1}
    }}
    {title "font" type table content {
        {configure   {font configure TkDefaultFont -size 11}   1}
        {create      {font create myFont -family Helvetica -size 12} 1}
        {measure     {font measure myFont "text"}              1}
        {metrics     {font metrics myFont -ascent}             1}
        {families    {font families}                           1}
    }}
}
