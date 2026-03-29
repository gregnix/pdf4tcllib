#!/usr/bin/env wish
# ===========================================================================
# Demo 55: Canvas Items Matrix -- alle Items, sofort sichtbar was fehlt
# ===========================================================================
#
# Zeigt alle tk::canvas und tko::path Items in einer Tabelle:
#   Spalte 1: Item-Name + Aufruf-Syntax
#   Spalte 2: tk::canvas Darstellung (screen)
#   Spalte 3: tko::path  Darstellung (screen, antialiased)
#   Spalte 4: pdf4tcl canvas Export (PDF-Seite)
#   Spalte 5: Status: OK / FEHLT / SCREEN-ONLY
#
# PDF-Seite zeigt dieselbe Tabelle -- sofort sichtbar was im PDF fehlt.
#
# Usage: wish examples/advanced/55_canvas_items_matrix.tcl [outputdir]
# Requires: tko (optional, ohne tko wird Spalte 3 uebersprungen)
# ===========================================================================

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set hasTko [expr {![catch {package require tko}]}]
catch { set ::path::antialias 1 }

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_55_canvas_items_matrix.pdf"]

# ===========================================================================
# Item-Definitionen
# Jede Zeile: {name syntax canvas_draw_script tko_draw_script status note}
# status: ok / partial / screen-only / missing
# ===========================================================================

# Zellen-Dimensionen
set CW 120   ;# cell width
set CH 70    ;# cell height
set PAD 6    ;# padding inside cell

set items {
    {
        "rectangle"
        "$w create rect x1 y1 x2 y2"
        {
            %W create rectangle 5 8 [expr {%CW-5}] [expr {%CH-8}] \
                -fill "#b3d1f0" -outline "#0055aa" -width 2
        }
        {
            %W create rect 5 8 [expr {%CW-5}] [expr {%CH-8}] -rx 0 \
                -fill "#b3d1f0" -stroke "#0055aa" -strokewidth 2
        }
        "ok"
        "Vollstaendig. tko: rect statt rectangle"
    }
    {
        "rectangle -dash"
        "$w create rect ... -dash"
        {
            %W create rectangle 5 8 [expr {%CW-5}] [expr {%CH-8}] \
                -fill "" -outline "#cc3300" -width 2 -dash {6 3}
        }
        {
            %W create rect 5 8 [expr {%CW-5}] [expr {%CH-8}] \
                -fill "" -stroke "#cc3300" -strokewidth 2 \
                -strokedasharray {6 3}
        }
        "ok"
        "tko: -strokedasharray statt -dash"
    }
    {
        "rect -rx (tko)"
        "tko only: -rx -ry"
        {
            %W create rectangle 5 8 [expr {%CW-5}] [expr {%CH-8}] \
                -fill "#ffe066" -outline "#cc8800" -width 2
        }
        {
            %W create rect 5 8 [expr {%CW-5}] [expr {%CH-8}] -rx 12 \
                -fill "#ffe066" -stroke "#cc8800" -strokewidth 2
        }
        "ok"
        "Abgerundete Ecken: tko only, exportiert"
    }
    {
        "oval / circle"
        "oval: bbox  circle: cx cy -r"
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            %W create oval [expr {$cx-28}] [expr {$cy-25}] \
                           [expr {$cx+28}] [expr {$cy+25}] \
                -fill "#ffcccc" -outline "#cc0000" -width 2
        }
        {
            %W create circle [expr {%CW/2}] [expr {%CH/2}] -r 28 \
                -fill "#ffcccc" -stroke "#cc0000" -strokewidth 2
        }
        "ok"
        "canvas: bbox. tko: Mittelpunkt + -r. Beide exportieren"
    }
    {
        "oval leer"
        "-fill {} (kein Fill)"
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            %W create oval [expr {$cx-28}] [expr {$cy-25}] \
                           [expr {$cx+28}] [expr {$cy+25}] \
                -fill "" -outline "#0000cc" -width 2
        }
        {
            %W create circle [expr {%CW/2}] [expr {%CH/2}] -r 28 \
                -fill "" -stroke "#0000cc" -strokewidth 2
        }
        "ok"
        "Rahmen ohne Fuellung: exportiert"
    }
    {
        "ellipse (tko)"
        "tko only: cx cy -rx -ry"
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            %W create oval [expr {$cx-50}] [expr {$cy-18}] \
                           [expr {$cx+50}] [expr {$cy+18}] \
                -fill "#ccffcc" -outline "#006600" -width 1
        }
        {
            %W create ellipse [expr {%CW/2}] [expr {%CH/2}] \
                -rx 50 -ry 18 \
                -fill "#ccffcc" -stroke "#006600" -strokewidth 1
        }
        "ok"
        "tko ellipse mit getrennten Radien: exportiert"
    }
    {
        "line"
        "$w create line x1 y1 x2 y2"
        {
            %W create line 8 [expr {%CH/2}] [expr {%CW-8}] [expr {%CH/2}] \
                -fill black -width 2
            %W create line 8 [expr {%CH/2+12}] [expr {%CW-8}] [expr {%CH/2+12}] \
                -fill "#0055aa" -width 2 -dash {8 3}
        }
        {
            %W create line 8 [expr {%CH/2}] [expr {%CW-8}] [expr {%CH/2}] \
                -stroke black -strokewidth 2
            %W create line 8 [expr {%CH/2+12}] [expr {%CW-8}] [expr {%CH/2+12}] \
                -stroke "#0055aa" -strokewidth 2 -strokedasharray {8 3}
        }
        "ok"
        "Einfaches Muster: exportiert. tko: -strokedasharray statt -dash. Komplex: naechste Zeile"
    }
    {
        "line -dash komplex"
        "-dash {10 3 2 3} (4 Elemente)"
        {
            # canvas: komplexes Muster Strich-Lücke-Punkt-Lücke
            %W create line 8 [expr {%CH/2-10}] [expr {%CW-8}] [expr {%CH/2-10}] \
                -fill "#0055aa" -width 2 -dash {10 3 2 3}
            %W create line 8 [expr {%CH/2+6}] [expr {%CW-8}] [expr {%CH/2+6}] \
                -fill "#cc3300" -width 2 -dash {8 2 2 2 2 2}
        }
        {
            # tko: -strokedasharray mit >2 Elementen
            %W create line 8 [expr {%CH/2-10}] [expr {%CW-8}] [expr {%CH/2-10}] \
                -stroke "#0055aa" -strokewidth 2 -strokedasharray {10 3 2 3}
            %W create line 8 [expr {%CH/2+6}] [expr {%CW-8}] [expr {%CH/2+6}] \
                -stroke "#cc3300" -strokewidth 2 -strokedasharray {8 2 2 2 2 2}
        }
        "partial"
        "canvas+tko: beliebig viele Elemente. pdf4tcl: nur 2 Werte (dash gap) -- komplexe Muster verloren"
    }
    {
        "line -dashoffset"
        "-dashoffset N  (Versatz)"
        {
            # canvas: Versatz im Strichmuster
            %W create line 8 [expr {%CH/2-10}] [expr {%CW-8}] [expr {%CH/2-10}] \
                -fill "#006600" -width 2 -dash {8 4} -dashoffset 0
            %W create line 8 [expr {%CH/2+8}] [expr {%CW-8}] [expr {%CH/2+8}] \
                -fill "#cc6600" -width 2 -dash {8 4} -dashoffset 6
        }
        {
            # tko: kein -dashoffset; nur approximate
            %W create line 8 [expr {%CH/2-10}] [expr {%CW-8}] [expr {%CH/2-10}] \
                -stroke "#006600" -strokewidth 2 -strokedasharray {8 4}
            %W create text [expr {%CW/2}] [expr {%CH-10}] \
                -text "(kein offset)" -fontsize 8 -fill "#999" -textanchor middle
        }
        "missing"
        "canvas: -dashoffset verschiebt Startpunkt im Muster. pdf4tcl + tko: nicht unterstuetzt"
    }
    {
        "line -capstyle"
        "-capstyle butt|round|projecting"
        {
            foreach {y cap col} {
                15 butt      "#0055aa"
                35 round     "#006600"
                55 projecting "#cc3300"
            } {
                %W create line 20 $y [expr {%CW-20}] $y \
                    -fill $col -width 10 -capstyle $cap
            }
        }
        {
            foreach {y cap col} {
                15 butt   "#0055aa"
                35 round  "#006600"
                55 square "#cc3300"
            } {
                %W create line 20 $y [expr {%CW-20}] $y \
                    -stroke $col -strokewidth 10 -strokelinecap $cap
            }
        }
        "partial"
        "canvas: butt/round/projecting. tko: butt/round/square (-strokelinecap). pdf4tcl canvas-Export ignoriert capstyle"
    }
    {
        "line -joinstyle"
        "-joinstyle miter|round|bevel"
        {
            set pts [list 10 [expr {%CH-10}] [expr {%CW/2}] 10 [expr {%CW-10}] [expr {%CH-10}]]
            foreach {y js col} {
                0 miter  "#0055aa"
                0 round  "#cc3300"
                0 bevel  "#006600"
            } break
            # Drei Winkel nebeneinander
            foreach {ox js col} {5 miter "#0055aa"  40 round "#cc3300"  75 bevel "#006600"} {
                %W create line [expr {$ox}] [expr {%CH-15}] \
                               [expr {$ox+20}] 10 \
                               [expr {$ox+40}] [expr {%CH-15}] \
                    -fill $col -width 4 -joinstyle $js
            }
        }
        {
            foreach {ox js col} {5 miter "#0055aa"  40 round "#cc3300"  75 bevel "#006600"} {
                %W create polyline [expr {$ox}] [expr {%CH-15}] \
                                   [expr {$ox+20}] 10 \
                                   [expr {$ox+40}] [expr {%CH-15}] \
                    -stroke $col -strokewidth 4 -strokelinejoin $js
            }
        }
        "partial"
        "canvas: -joinstyle. tko: -strokelinejoin (miter/round/bevel). pdf4tcl canvas-Export ignoriert joinstyle"
    }
    {
        "line -smooth"
        "-smooth true (Bezierkurve)"
        {
            %W create line 8 [expr {%CH-10}] \
                             [expr {%CW/3}] 10 \
                             [expr {%CW*2/3}] [expr {%CH-10}] \
                             [expr {%CW-8}] 10 \
                -fill "#0055aa" -width 2 -smooth 0
            %W create line 8 [expr {%CH*0.65}] \
                             [expr {%CW/3}] [expr {%CH*0.15}] \
                             [expr {%CW*2/3}] [expr {%CH*0.65}] \
                             [expr {%CW-8}] [expr {%CH*0.15}] \
                -fill "#cc3300" -width 2 -smooth 1
        }
        {
            # tko: path mit C (kubische Bezier)
            %W create line 8 [expr {%CH-10}] \
                             [expr {%CW/3}] 10 \
                             [expr {%CW*2/3}] [expr {%CH-10}] \
                             [expr {%CW-8}] 10 \
                -stroke "#0055aa" -strokewidth 2
            %W create path "M 8 [expr {%CH*0.65}] C [expr {%CW/3}] [expr {%CH*0.15}] [expr {%CW*2/3}] [expr {%CH*0.65}] [expr {%CW-8}] [expr {%CH*0.15}]" \
                -fill "" -stroke "#cc3300" -strokewidth 2
        }
        "partial"
        "canvas -smooth: Spline wird exportiert. pdf4tcl: als gerade Segmente (kein Spline im Canvas-Export)"
    }
    {
        "line -arrow"
        "-arrow last/first/both"
        {
            %W create line 8 [expr {%CH/2}] [expr {%CW-8}] [expr {%CH/2}] \
                -fill "#cc3300" -width 2 -arrow last
            %W create line 8 [expr {%CH/2+15}] [expr {%CW-8}] [expr {%CH/2+15}] \
                -fill "#006600" -width 2 -arrow both
        }
        {
            %W create line 8 [expr {%CH/2}] [expr {%CW-8}] [expr {%CH/2}] \
                -stroke "#cc3300" -strokewidth 2 -endarrow 1
            %W create line 8 [expr {%CH/2+15}] [expr {%CW-8}] [expr {%CH/2+15}] \
                -stroke "#006600" -strokewidth 2 -endarrow 1 -startarrow 1
        }
        "ok"
        "canvas: -arrow last/both. tko: -endarrow/-startarrow"
    }
    {
        "polygon"
        "$w create polygon x y x y ..."
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            set pts [list $cx [expr {$cy-25}] \
                         [expr {$cx+28}] [expr {$cy+18}] \
                         [expr {$cx-28}] [expr {$cy+18}]]
            %W create polygon {*}$pts \
                -fill "#ddeeff" -outline "#003399" -width 2
        }
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            set pts [list $cx [expr {$cy-25}] \
                         [expr {$cx+28}] [expr {$cy+18}] \
                         [expr {$cx-28}] [expr {$cy+18}]]
            %W create polygon {*}$pts \
                -fill "#ddeeff" -stroke "#003399" -strokewidth 2
        }
        "ok"
        "Gleiche Syntax. Exportiert"
    }
    {
        "arc"
        "$w create arc x1 y1 x2 y2 -start -extent"
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            %W create arc [expr {$cx-30}] [expr {$cy-28}] \
                          [expr {$cx+30}] [expr {$cy+28}] \
                -start 45 -extent 270 -style pieslice \
                -fill "#ffd0a0" -outline "#cc6600" -width 2
        }
        {
            # tko::path: SVG arc syntax
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            set r 28
            # 45 Grad Start, 270 Grad Extent -- als path
            set a1 [expr {45.0 * 3.14159/180.0}]
            set a2 [expr {(45.0+270.0) * 3.14159/180.0}]
            set x1 [expr {$cx + $r*cos($a1)}]
            set y1 [expr {$cy - $r*sin($a1)}]
            set x2 [expr {$cx + $r*cos($a2)}]
            set y2 [expr {$cy - $r*sin($a2)}]
            %W create path \
                "M $cx $cy L $x1 $y1 A $r $r 0 1 0 $x2 $y2 Z" \
                -fill "#ffd0a0" -stroke "#cc6600" -strokewidth 2
        }
        "ok"
        "canvas: arc Item. tko: SVG path A. Beide exportieren"
    }
    {
        "arc -style chord"
        "-style chord/arc"
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            %W create arc [expr {$cx-30}] [expr {$cy-28}] \
                          [expr {$cx+30}] [expr {$cy+28}] \
                -start 0 -extent 180 -style chord \
                -fill "#b0e0ff" -outline "#0055aa" -width 2
        }
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            %W create path "M [expr {$cx-30}] $cy A 30 28 0 0 1 [expr {$cx+30}] $cy Z" \
                -fill "#b0e0ff" -stroke "#0055aa" -strokewidth 2
        }
        "ok"
        "Sehne: canvas -style chord. tko: SVG path"
    }
    {
        "text"
        "$w create text x y -text ..."
        {
            %W create text [expr {%CW/2}] [expr {%CH*0.35}] \
                -text "Normal" -font {Helvetica 11} -fill black -anchor center
            %W create text [expr {%CW/2}] [expr {%CH*0.65}] \
                -text "Bold" -font {Helvetica 11 bold} \
                -fill "#003399" -anchor center
        }
        {
            %W create text [expr {%CW/2}] [expr {%CH*0.35}] \
                -text "Normal" -fontsize 11 -fill black -textanchor middle
            %W create text [expr {%CW/2}] [expr {%CH*0.65}] \
                -text "Bold" -fontsize 11 -fontweight bold \
                -fill "#003399" -textanchor middle
        }
        "ok"
        "Exportiert. tko: -fontsize -fontweight statt -font"
    }
    {
        "text italic"
        "-font {... italic}"
        {
            %W create text [expr {%CW/2}] [expr {%CH*0.35}] \
                -text "Italic" -font {Helvetica 11 italic} \
                -fill "#cc3300" -anchor center
            %W create text [expr {%CW/2}] [expr {%CH*0.65}] \
                -text "Courier" -font {Courier 10} \
                -fill "#006600" -anchor center
        }
        {
            %W create text [expr {%CW/2}] [expr {%CH*0.35}] \
                -text "Italic" -fontsize 11 -fontslant italic \
                -fill "#cc3300" -textanchor middle
            %W create text [expr {%CW/2}] [expr {%CH*0.65}] \
                -text "Courier" -fontsize 10 -fontfamily Courier \
                -fill "#006600" -textanchor middle
        }
        "ok"
        "tko: -fontslant -fontfamily"
    }
    {
        "image"
        "$w create image x y -image ..."
        {
            # Kleines Test-Bild erstellen
            if {![info exists ::testImg]} {
                set ::testImg [image create photo -width 40 -height 30]
                for {set row 0} {$row < 30} {incr row} {
                    for {set col 0} {$col < 40} {incr col} {
                        set r [expr {int(200*$col/40.0)}]
                        set g [expr {int(150*$row/30.0)}]
                        set b 180
                        $::testImg put [format "#%02x%02x%02x" $r $g $b] \
                            -to $col $row
                    }
                }
            }
            %W create image [expr {%CW/2}] [expr {%CH/2}] \
                -image $::testImg -anchor center
        }
        {
            if {![info exists ::testImg]} {
                set ::testImg [image create photo -width 40 -height 30]
                for {set row 0} {$row < 30} {incr row} {
                    for {set col 0} {$col < 40} {incr col} {
                        set r [expr {int(200*$col/40.0)}]
                        set g [expr {int(150*$row/30.0)}]
                        set b 180
                        $::testImg put [format "#%02x%02x%02x" $r $g $b] \
                            -to $col $row
                    }
                }
            }
            %W create image [expr {%CW/2}] [expr {%CH/2}] \
                -image $::testImg -anchor c
        }
        "ok"
        "Photo-Image exportiert als Bitmap"
    }
    {
        "path (tko)"
        "tko only: SVG M L C Q A Z"
        {
            # canvas hat kein path-Item -- Polygon-Näherung
            set cx [expr {%CW/2}]; set cy [expr {%CH/2}]
            set pts {}
            for {set i 0} {$i < 10} {incr i} {
                set r [expr {($i%2) ? 12 : 28}]
                set a [expr {-3.14159/2.0 + $i*3.14159/5.0}]
                lappend pts [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]
            }
            %W create polygon {*}$pts \
                -fill "#ffe066" -outline "#cc8800" -width 1
            %W create text [expr {%CW/2}] [expr {%CH-10}] \
                -text "(polygon)" -font {Helvetica 7 italic} \
                -fill "#999999" -anchor center
        }
        {
            set cx [expr {%CW/2}]; set cy [expr {%CH/2-5}]
            set pd "M"
            for {set i 0} {$i < 10} {incr i} {
                set r [expr {($i%2) ? 12 : 28}]
                set a [expr {-3.14159/2.0 + $i*3.14159/5.0}]
                if {$i==0} {
                    append pd " [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]"
                } else {
                    append pd " L [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]"
                }
            }
            append pd " Z"
            %W create path $pd \
                -fill "#ffe066" -stroke "#cc8800" -strokewidth 1
        }
        "ok"
        "tko path: SVG-Syntax. Exportiert mit -bbox all"
    }
    {
        "-fillopacity (tko)"
        "tko only: -fillopacity 0..1"
        {
            # canvas hat keine Transparenz
            foreach {dx col} {10 "#cc3300" 40 "#0055aa" 25 "#006600"} {
                %W create oval [expr {$dx}] [expr {%CH/2-18}] \
                               [expr {$dx+36}] [expr {%CH/2+18}] \
                    -fill $col -outline ""
            }
            %W create text [expr {%CW/2}] [expr {[expr {%CH-8}]}] \
                -text "(solid, kein alpha)" \
                -font {Helvetica 7 italic} -fill "#999" -anchor center
        }
        {
            foreach {cx col} {25 "#cc3300" 60 "#0055aa" 42 "#006600"} {
                %W create circle $cx [expr {%CH/2}] -r 20 \
                    -fill $col -fillopacity 0.55 \
                    -stroke "" -strokewidth 0
            }
        }
        "screen-only"
        "fillopacity: sichtbar im tko Screen. Im PDF: solid (keine Transparenz)"
    }
    {
        "gradient (tko)"
        "tko::path::gradient"
        {
            # canvas: kein Gradient, Annäherung mit Rechtecken
            for {set i 0} {$i < 10} {incr i} {
                set x [expr {5 + $i*11}]
                set r [expr {int(180 - $i*15)}]
                set g [expr {int(100 + $i*10)}]
                set b [expr {int(50 + $i*5)}]
                %W create rectangle $x 15 [expr {$x+12}] [expr {%CH-15}] \
                    -fill [format "#%02x%02x%02x" $r $g $b] -outline ""
            }
            %W create text [expr {%CW/2}] [expr {[expr {%CH-8}]}] \
                -text "(simuliert)" \
                -font {Helvetica 7 italic} -fill "#999" -anchor center
        }
        {
            if {$::hasTko} {
                set g [%W gradient create linear \
                    -stops {{0 "#ff6644"} {0.5 "#ffee44"} {1 "#44cc66"}}]
                %W create rect 5 15 [expr {[expr {%CW-5}]}] [expr {%CH-15}] -fill $g
            }
        }
        "screen-only"
        "Gradient: sichtbar im tko Screen. Im PDF: Fallback (keine Uebertragung)"
    }
    {
        "window"
        "$w create window x y -window w"
        {
            button %W.b -text "Button" -relief raised -pady 2 -padx 8 \
                -font {Helvetica 9}
            %W create window [expr {%CW/2}] [expr {%CH/2}] \
                -window %W.b -anchor center
        }
        {
            # tko hat window-Item ebenfalls
            button %W.b2 -text "Button" -relief raised -pady 2 -padx 8 \
                -font {Helvetica 9}
            %W create window [expr {%CW/2}] [expr {%CH/2}] \
                -window %W.b2 -anchor center
        }
        "missing"
        "window: nicht exportierbar (kein Vektor). Workaround: Screenshot als image"
    }
    {
        "dash Kurzform"
        "-dash \".\"-\"-.-\" (shape-conserving)"
        {
            # Zeichenketten-Kurznotation -- shape-conserving (x linewidth)
            foreach {y pat lbl} {
                10 "."  "."
                22 "-"  "-"
                34 "-." "-."
                46 "-.." "-.."
                58 ","  ","
            } {
                %W create line 5 $y [expr {%CW*0.65}] $y                     -fill "#0055aa" -width 2 -dash $pat
                %W create text [expr {%CW*0.7}] $y                     -text $lbl -font {Courier 8} -fill "#555" -anchor w
            }
        }
        {
            # tko: keine Kurznotation, nur Zahlen-Liste
            foreach {y pat} {10 {2 4}  22 {6 4}  34 {6 4 2 4}  46 {6 4 2 4 2 4}  58 {4 4}} {
                %W create line 5 $y [expr {%CW*0.65}] $y                     -stroke "#0055aa" -strokewidth 2 -strokedasharray $pat
            }
            %W create text [expr {%CW/2}] [expr {[expr {%CH-8}]}]                 -text "(nur Zahlen)" -fontsize 8 -fill "#999" -textanchor middle
        }
        "missing"
        "canvas: '.' '-' etc. sind shape-conserving (Muster * linewidth). pdf4tcl + tko: nur Zahlen-Liste, kein shape-conserving"
    }
    {
        "text -angle"
        "-angle degrees (ab Tk 8.6)"
        {
            %W create text [expr {%CW*0.3}] [expr {%CH*0.6}]                 -text "0°" -font {Helvetica 9} -fill "#0055aa"                 -angle 0 -anchor center
            %W create text [expr {%CW*0.55}] [expr {%CH*0.6}]                 -text "45°" -font {Helvetica 9} -fill "#cc3300"                 -angle 45 -anchor center
            %W create text [expr {%CW*0.78}] [expr {%CH*0.55}]                 -text "90°" -font {Helvetica 9} -fill "#006600"                 -angle 90 -anchor center
        }
        {
            # tko: -matrix rotate für Text-Rotation
            set cx [expr {%CW*0.3}]; set cy [expr {%CH*0.6}]
            %W create text $cx $cy -text "0°"                 -fontsize 9 -fill "#0055aa" -textanchor middle
            set cx2 [expr {%CW*0.55}]; set cy2 [expr {%CH*0.6}]
            %W create text $cx2 $cy2 -text "45°" \
                -fontsize 9 -fill "#cc3300" -textanchor middle \
                -matrix {0.707 0.707 -0.707 0.707 0 0}
            set cx3 [expr {%CW*0.78}]; set cy3 [expr {%CH*0.55}]
            %W create text $cx3 $cy3 -text "90°" \
                -fontsize 9 -fill "#006600" -textanchor middle \
                -matrix {0 1 -1 0 0 0}
        }
        "partial"
        "missing"
        "canvas: -angle direkt. tko: -matrix. pdf4tcl Export: Rotation geht verloren -- CanvasDoTkoPathItem x1 Fehler bei Matrix-Text"
    }
    {
        "text -underline"
        "-underline index"
        {
            %W create text [expr {%CW/2}] [expr {%CH*0.35}]                 -text "Underlined" -font {Helvetica 11}                 -fill "#003399" -anchor center -underline 0
            %W create text [expr {%CW/2}] [expr {%CH*0.65}]                 -text "Mid Word" -font {Helvetica 11}                 -fill "#cc3300" -anchor center -underline 4
        }
        {
            # tko hat kein -underline
            %W create text [expr {%CW/2}] [expr {%CH*0.35}]                 -text "Underlined" -fontsize 11                 -fill "#003399" -textanchor middle
            %W create text [expr {%CW/2}] [expr {%CH*0.65}]                 -text "(kein -underline)" -fontsize 9                 -fill "#999999" -textanchor middle
        }
        "missing"
        "canvas: -underline N unterstreicht Zeichen N. tko: kein Äquivalent. pdf4tcl: kein Underline (Linie separat zeichnen)"
    }
    {
        "active/disabled States"
        "-activefill -disabledfill"
        {
            # State-abhängige Farben: hover=active, disabled=ausgegraut
            %W create rectangle 8 10 [expr {%CW/2-4}] [expr {%CH-10}]                 -fill "#b3d1f0" -outline "#0055aa"                 -activefill "#ffee88" -activeoutline "#cc8800"                 -width 2 -tags demo_state
            %W create text [expr {%CW/4+4}] [expr {%CH/2}]                 -text "hover!" -font {Helvetica 8} -fill "#333" -anchor center
            %W create rectangle [expr {%CW/2+4}] 10 [expr {%CW-8}] [expr {%CH-10}]                 -fill "#cccccc" -outline "#888888"                 -disabledfill "#eeeeee"                 -width 1 -state disabled
            %W create text [expr {%CW*0.75+4}] [expr {%CH/2}]                 -text "disabled" -font {Helvetica 8} -fill "#999" -anchor center
        }
        {
            # tko: kein active/disabled state
            %W create rect 8 10 [expr {%CW/2-4}] [expr {%CH-10}]                 -fill "#b3d1f0" -stroke "#0055aa" -strokewidth 2
            %W create rect [expr {%CW/2+4}] 10 [expr {%CW-8}] [expr {%CH-10}]                 -fill "#cccccc" -stroke "#888888" -strokewidth 1
            %W create text [expr {%CW/2}] [expr {%CH-10}]                 -text "(kein active/disabled)"                 -fontsize 8 -fill "#999" -textanchor middle
        }
        "missing"
        "canvas: -activefill/-disabledfill etc. reagieren auf Hover/State. pdf4tcl + tko: kein State-Konzept im Export"
    }
    {
        "polygon -smooth raw"
        "-smooth raw (Kubische Bezier)"
        {
            # raw: jeder 3. Punkt ist Knoten, andere sind Kontrollpunkte
            set pts {
                30 60
                20 10  80 10  70 60
                80 110 20 110 30 60
            }
            %W create polygon {*}$pts                 -fill "#ddeeff" -outline "#003399" -width 2                 -smooth raw
            %W create polygon {*}$pts                 -fill "" -outline "#cc330077" -width 1                 -smooth 0
        }
        {
            # tko: path mit C (explizite Kontrollpunkte)
            %W create path "M 30 60 C 20 10 80 10 70 60 C 80 110 20 110 30 60 Z"                 -fill "#ddeeff" -stroke "#003399" -strokewidth 2
        }
        "ok"
        "canvas: -smooth raw mit expliziten Kontrollpunkten. tko: path C. Beide exportieren korrekt"
    }
    {
        "bitmap"
        "$w create bitmap x y -bitmap name"
        {
            %W create bitmap [expr {%CW/2}] [expr {%CH/2}] \
                -bitmap questhead -foreground "#0055aa" -anchor center
        }
        {
            # tko hat kein bitmap-Item -- image stattdessen
            %W create text [expr {%CW/2}] [expr {%CH/2}] \
                -text "n/a" -fontsize 11 -fill "#999999" -textanchor middle
        }
        "missing"
        "bitmap: canvas only, tko hat kein Bitmap-Item, nicht exportierbar"
    }
}

# ===========================================================================
# Status-Farben
# ===========================================================================
array set statusColor {
    ok          "#006600"
    partial     "#cc8800"
    screen-only "#cc6600"
    missing     "#cc0000"
}
array set statusLabel {
    ok          "OK"
    partial     "TEILWEISE"
    screen-only "SCREEN ONLY"
    missing     "FEHLT"
}
array set statusBg {
    ok          "#e8ffe8"
    partial     "#fff8e0"
    screen-only "#fff0d8"
    missing     "#ffe8e8"
}

# ===========================================================================
# Hilfsproc: Script in Canvas-Widget ausführen
# Ersetzt %W -> Widget-Pfad, %CW/%CH -> Zellbreite/-höhe
# ===========================================================================
proc runInCanvas {w script cw ch} {
    set s [string map [list %W $w %CW $cw %CH $ch] $script]
    if {[catch {uplevel 1 $s} err]} {
        # Fehler anzeigen aber nicht abbrechen
        catch {$w create text [expr {$cw/2}] [expr {$ch/2}] \
            -text "ERR" -fill red -anchor center}
    }
}

# ===========================================================================
# GUI aufbauen
# ===========================================================================
wm title . "Demo 55: Canvas Items Matrix"

# Header
frame .hdr -pady 6
pack .hdr -fill x
label .hdr.t -text "Demo 55: Canvas Items -- vollstaendige Uebersicht" \
    -font {Helvetica 12 bold}
pack .hdr.t

# Legende
frame .leg -pady 4
pack .leg
foreach {st} {ok screen-only missing} {
    frame .leg.$st -bg $statusBg($st) -relief solid -borderwidth 1 \
        -padx 6 -pady 2
    pack .leg.$st -side left -padx 4
    label .leg.$st.l -text $statusLabel($st) -fg $statusColor($st) \
        -bg $statusBg($st) -font {Helvetica 9 bold}
    pack .leg.$st.l
}

# Scroll-Container
frame .main
pack .main -fill both -expand 1

canvas .main.scroll -yscrollcommand {.main.sb set} -bg "#f5f5f5"
scrollbar .main.sb -orient vertical -command {.main.scroll yview}
pack .main.sb -side right -fill y
pack .main.scroll -side left -fill both -expand 1

frame .main.scroll.inner -bg "#f5f5f5"
.main.scroll create window 0 0 -anchor nw -window .main.scroll.inner

# Spalten-Header
set cols {
    {"Item / Syntax"    200}
    {"tk::canvas"       130}
    {"tko::path"        130}
    {"PDF Export"       130}
    {"Status"           110}
    {"Hinweis"          260}
}

set hf {Helvetica 9 bold}
set row 0
set col 0
foreach {hdr} $cols {
    lassign $hdr txt wd
    frame .main.scroll.inner.h$col -width $wd -height 28 \
        -bg "#334466" -relief flat
    grid .main.scroll.inner.h$col -row 0 -column $col -padx 1 -pady 1 -sticky nsew
    label .main.scroll.inner.h$col.l -text $txt -fg white -bg "#334466" \
        -font $hf -wraplength [expr {$wd-4}]
    pack .main.scroll.inner.h$col.l -fill both -expand 1
    incr col
}

# Item-Zeilen
set rowIdx 1
foreach item $items {
    lassign $item name syntax canvas_script tko_script status note

    set bg [expr {$rowIdx%2 ? "#ffffff" : "#f8f8f8"}]
    set sbg $statusBg($status)

    # Spalte 0: Name + Syntax
    frame .main.scroll.inner.r${rowIdx}c0 -width 200 -height $CH \
        -bg $bg -relief flat
    grid .main.scroll.inner.r${rowIdx}c0 -row $rowIdx -column 0 \
        -padx 1 -pady 1 -sticky nsew
    label .main.scroll.inner.r${rowIdx}c0.name \
        -text $name -font {Helvetica 9 bold} -bg $bg -fg "#1a1a1a" \
        -anchor w -wraplength 194
    label .main.scroll.inner.r${rowIdx}c0.syn \
        -text $syntax -font {Courier 7} -bg $bg -fg "#555555" \
        -anchor w -wraplength 194
    pack .main.scroll.inner.r${rowIdx}c0.name -fill x -padx 4 -pady 1
    pack .main.scroll.inner.r${rowIdx}c0.syn  -fill x -padx 4

    # Spalte 1: tk::canvas
    frame .main.scroll.inner.r${rowIdx}c1 -width $CW -height $CH \
        -bg white -relief sunken -borderwidth 1
    grid .main.scroll.inner.r${rowIdx}c1 -row $rowIdx -column 1 \
        -padx 1 -pady 1 -sticky nsew
    canvas .main.scroll.inner.r${rowIdx}c1.c \
        -width $CW -height $CH -bg white -highlightthickness 0
    pack .main.scroll.inner.r${rowIdx}c1.c
    runInCanvas .main.scroll.inner.r${rowIdx}c1.c $canvas_script $CW $CH

    # Spalte 2: tko::path
    frame .main.scroll.inner.r${rowIdx}c2 -width $CW -height $CH \
        -bg white -relief sunken -borderwidth 1
    grid .main.scroll.inner.r${rowIdx}c2 -row $rowIdx -column 2 \
        -padx 1 -pady 1 -sticky nsew
    if {$hasTko} {
        tko::path .main.scroll.inner.r${rowIdx}c2.p \
            -width $CW -height $CH -background white \
            -highlightthickness 0
        pack .main.scroll.inner.r${rowIdx}c2.p
        runInCanvas .main.scroll.inner.r${rowIdx}c2.p $tko_script $CW $CH
    } else {
        label .main.scroll.inner.r${rowIdx}c2.l \
            -text "tko\nn/a" -bg "#f0f0f0" -fg "#999999" \
            -font {Helvetica 8 italic}
        pack .main.scroll.inner.r${rowIdx}c2.l -fill both -expand 1
    }

    # Spalte 3: PDF Export (Vorschau -- wird beim Export befüllt)
    frame .main.scroll.inner.r${rowIdx}c3 -width $CW -height $CH \
        -bg "#f8f8ff" -relief sunken -borderwidth 1
    grid .main.scroll.inner.r${rowIdx}c3 -row $rowIdx -column 3 \
        -padx 1 -pady 1 -sticky nsew
    # PDF-Vorschau: copy des canvas-Widgets (gleicher Inhalt, anderer Rahmen)
    canvas .main.scroll.inner.r${rowIdx}c3.c \
        -width $CW -height $CH -bg "#f8f8ff" -highlightthickness 0
    pack .main.scroll.inner.r${rowIdx}c3.c
    runInCanvas .main.scroll.inner.r${rowIdx}c3.c $canvas_script $CW $CH

    # Spalte 4: Status-Badge
    frame .main.scroll.inner.r${rowIdx}c4 -width 110 -height $CH \
        -bg $sbg -relief flat
    grid .main.scroll.inner.r${rowIdx}c4 -row $rowIdx -column 4 \
        -padx 1 -pady 1 -sticky nsew
    label .main.scroll.inner.r${rowIdx}c4.l \
        -text $statusLabel($status) \
        -fg $statusColor($status) -bg $sbg \
        -font {Helvetica 9 bold} -wraplength 104
    pack .main.scroll.inner.r${rowIdx}c4.l -fill both -expand 1

    # Spalte 5: Hinweis
    frame .main.scroll.inner.r${rowIdx}c5 -width 260 -height $CH \
        -bg $bg -relief flat
    grid .main.scroll.inner.r${rowIdx}c5 -row $rowIdx -column 5 \
        -padx 1 -pady 1 -sticky nsew
    label .main.scroll.inner.r${rowIdx}c5.l \
        -text $note -fg "#444444" -bg $bg \
        -font {Helvetica 8} -wraplength 254 -justify left -anchor w
    pack .main.scroll.inner.r${rowIdx}c5.l -fill both -expand 1 -padx 4

    incr rowIdx
}

# Scroll-Region aktualisieren
update idletasks
set bbox [.main.scroll bbox all]
.main.scroll configure -scrollregion $bbox -width 980 -height 600

# ===========================================================================
# Buttons
# ===========================================================================
frame .btns -pady 8
pack .btns
button .btns.exp -text "PDF exportieren" -command exportPDF \
    -font {Helvetica 10 bold} -bg "#0055aa" -fg white -relief raised \
    -padx 12 -pady 4
button .btns.q -text "Schliessen" -command exit -padx 8
pack .btns.exp .btns.q -side left -padx 6

# ===========================================================================
# PDF Export
# ===========================================================================
proc exportPDF {} {
    global items statusColor statusLabel statusBg CW CH outPDF hasTko

    set ctx [pdf4tcllib::page::context a4 -margin 15 -orient true]
    set lx   [dict get $ctx left]
    set top  [dict get $ctx top]
    set pdf  [::pdf4tcl::new %AUTO% -paper a4 -orient true]

    # --- Seite 1: Tabelle ---
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 55: Canvas Items -- Export-Matrix"
    pdf4tcllib::page::footer $pdf $ctx "OK=exportiert  SCREEN-ONLY=nur Bildschirm  FEHLT=nicht unterstuetzt" 1

    set y [expr {$top + 14}]

    # Spalten: Name/Syntax | canvas | tko | Status | Hinweis
    set colX    [list $lx \
                      [expr {$lx+160}] \
                      [expr {$lx+220}] \
                      [expr {$lx+280}] \
                      [expr {$lx+350}]]
    set colW    [list 158 58 58 68 210]
    set hdrTxt  [list "Item / Syntax" "canvas" "tko" "Status" "Hinweis"]

    # Header-Zeile
    $pdf setFillColor 0.2 0.27 0.4
    $pdf rectangle $lx $y [expr {[lindex $colX end]+[lindex $colW end]-$lx}] 14 -filled 1
    $pdf setFont 8 Helvetica-Bold
    $pdf setFillColor 1 1 1
    foreach x $colX txt $hdrTxt {
        $pdf text $txt -x [expr {$x+3}] -y [expr {$y+10}]
    }
    $pdf setFillColor 0 0 0
    set y [expr {$y+14}]

    # Canvas-Zeilen
    set rowH 44   ;# Zeilenhöhe im PDF (canvas CW x CH gescaled)
    set pCW 54    ;# canvas-Breite im PDF
    set pCH 40    ;# canvas-Höhe im PDF

    set rowIdx 0
    foreach item $items {
        lassign $item name syntax canvas_script tko_script status note

        # Zebra
        if {$rowIdx % 2 == 1} {
            $pdf setFillColor 0.96 0.96 0.98
            $pdf rectangle $lx $y \
                [expr {[lindex $colX end]+[lindex $colW end]-$lx}] $rowH -filled 1
            $pdf setFillColor 0 0 0
        }

        # Name + Syntax
        $pdf setFont 8 Helvetica-Bold
        $pdf text $name -x [expr {[lindex $colX 0]+2}] -y [expr {$y+12}]
        $pdf setFont 7 Courier
        $pdf setFillColor 0.3 0.3 0.3
        $pdf text [string range $syntax 0 28] \
            -x [expr {[lindex $colX 0]+2}] -y [expr {$y+22}]
        $pdf setFillColor 0 0 0

        # canvas-Widget in PDF
        set cw .main.scroll.inner.r[expr {$rowIdx+1}]c1.c
        if {[winfo exists $cw]} {
            $pdf canvas $cw \
                -x [lindex $colX 1] -y [expr {$y+2}] \
                -width $pCW -height $pCH
        }

        # tko-Widget in PDF (mit -bbox all)
        if {$hasTko} {
            set pw .main.scroll.inner.r[expr {$rowIdx+1}]c2.p
            if {[winfo exists $pw]} {
                set bb [$pw bbox all]
                if {$bb ne ""} {
                    if {[catch {
                        $pdf canvas $pw \
                            -bbox $bb \
                            -x [lindex $colX 2] -y [expr {$y+2}] \
                            -width $pCW -height $pCH
                    } err]} {
                        # Export-Fehler -- leer lassen (zeigt: kein Export)
                        puts stderr "tko export row $rowIdx ([lindex $items $rowIdx 0]): $err"
                        $pdf setFillColor 0.7 0.1 0.1
                        $pdf setFont 6 Helvetica
                        $pdf text "x (pdf4tcl Fehler)" \
                            -x [expr {[lindex $colX 2]+2}] \
                            -y [expr {$y+14}]
                        $pdf setFillColor 0 0 0
                    }
                }
            }
        }

        # Status-Badge
        lassign [switch $status {
            ok          { list 0 0.4 0 }
            partial     { list 0.8 0.5 0 }
            screen-only { list 0.8 0.4 0 }
            missing     { list 0.8 0.1 0.1 }
        }] sr sg sb
        $pdf setFillColor $sr $sg $sb
        $pdf setFont 7 Helvetica-Bold
        $pdf text $statusLabel($status) \
            -x [expr {[lindex $colX 3]+2}] -y [expr {$y+14}]
        $pdf setFillColor 0 0 0

        # Hinweis
        $pdf setFont 7 Helvetica
        $pdf setFillColor 0.25 0.25 0.25
        # Hinweis umbrechen
        set words [split $note " "]
        set line ""; set ly [expr {$y+10}]; set maxW 205
        foreach word $words {
            set test "$line $word"
            if {[$pdf getStringWidth [string trim $test]] > $maxW && $line ne ""} {
                $pdf text [string trim $line] \
                    -x [expr {[lindex $colX 4]+2}] -y $ly
                set line $word
                set ly [expr {$ly+9}]
            } else {
                set line $test
            }
        }
        if {$line ne ""} {
            $pdf text [string trim $line] \
                -x [expr {[lindex $colX 4]+2}] -y $ly
        }
        $pdf setFillColor 0 0 0

        # Trennlinie
        $pdf setStrokeColor 0.85 0.85 0.85
        $pdf setLineWidth 0.3
        $pdf line $lx [expr {$y+$rowH}] \
            [expr {[lindex $colX end]+[lindex $colW end]-$lx+$lx}] \
            [expr {$y+$rowH}]
        $pdf setStrokeColor 0 0 0

        set y [expr {$y + $rowH}]

        # Seitenumbruch?
        if {$y > [dict get $ctx bottom] - $rowH} {
            pdf4tcllib::page::footer $pdf $ctx \
                "OK=exportiert  SCREEN-ONLY=nur Bildschirm  FEHLT=nicht" \
                [expr {$rowIdx/10+1}]
            $pdf endPage
            $pdf startPage
            pdf4tcllib::page::header $pdf $ctx \
                "Demo 55: Canvas Items -- Export-Matrix (Fortsetzung)"
            set y [expr {$top + 14}]
            # Header wiederholen
            $pdf setFillColor 0.2 0.27 0.4
            $pdf rectangle $lx $y \
                [expr {[lindex $colX end]+[lindex $colW end]-$lx}] 14 -filled 1
            $pdf setFont 8 Helvetica-Bold
            $pdf setFillColor 1 1 1
            foreach x $colX txt $hdrTxt {
                $pdf text $txt -x [expr {$x+3}] -y [expr {$y+10}]
            }
            $pdf setFillColor 0 0 0
            set y [expr {$y+14}]
        }

        incr rowIdx
    }

    # Rahmen um Tabelle
    $pdf setStrokeColor 0.6 0.6 0.6
    $pdf setLineWidth 0.5

    # --- Seite letzte: Zusammenfassung ---
    $pdf endPage
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 55: Zusammenfassung"
    pdf4tcllib::page::footer $pdf $ctx "pdf4tcl + tko::path Canvas-Export" \
        [expr {int(ceil([llength $items]/10.0))+1}]

    set y [expr {$top + 20}]
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Zusammenfassung: Canvas-Item Export" -x $lx -y $y
    set y [expr {$y+20}]

    # Zählung
    set cnt_ok 0; set cnt_so 0; set cnt_miss 0
    foreach item $items {
        lassign $item name syntax cs ts status note
        switch $status {
            ok          { incr cnt_ok }
            screen-only { incr cnt_so }
            missing     { incr cnt_miss }
        }
    }

    $pdf setFont 10 Helvetica-Bold
    $pdf setFillColor 0 0.4 0
    $pdf text "Exportiert (OK): $cnt_ok Items" -x $lx -y $y
    set y [expr {$y+16}]
    $pdf setFillColor 0.8 0.4 0
    $pdf text "Nur Screen (SCREEN-ONLY): $cnt_so Items" -x $lx -y $y
    set y [expr {$y+16}]
    $pdf setFillColor 0.8 0.1 0.1
    $pdf text "Nicht exportierbar (FEHLT): $cnt_miss Items" -x $lx -y $y
    set y [expr {$y+24}]
    $pdf setFillColor 0 0 0

    $pdf setFont 9 Helvetica-Bold
    $pdf text "Was exportiert:" -x $lx -y $y
    set y [expr {$y+14}]
    $pdf setFont 9 Helvetica
    foreach line {
        "rectangle, oval, arc, line, polygon, text, image -- alle tk::canvas Items ausser window+bitmap"
        "rect, circle, ellipse, line, polyline, polygon, path, text -- alle tko::path Vektor-Items"
        "tko::path benoetigt: \$pdf canvas .p -bbox \[.p bbox all\] -x X -y Y"
    } {
        $pdf text $line -x [expr {$lx+10}] -y $y
        set y [expr {$y+13}]
    }
    set y [expr {$y+10}]

    $pdf setFont 9 Helvetica-Bold
    $pdf text "Was NICHT exportiert:" -x $lx -y $y
    set y [expr {$y+14}]
    $pdf setFont 9 Helvetica
    foreach line {
        "-fillopacity: Transparenz geht verloren, wird solid gerendert"
        "gradient: Farbverlauf fehlt im PDF (Fallback: schwarz oder weiss)"
        "window: Tk-Widget kann nicht vektorisiert werden"
        "bitmap: Tk-Bitmap-Item nicht unterstuetzt"
    } {
        $pdf setFillColor 0.7 0.1 0.1
        $pdf text "  x  " -x $lx -y $y
        $pdf setFillColor 0 0 0
        $pdf text $line -x [expr {$lx+20}] -y $y
        set y [expr {$y+13}]
    }

    $pdf endPage
    $pdf write -file $outPDF
    $pdf destroy

    .btns.exp configure \
        -text "Geschrieben: [file tail $outPDF]" \
        -bg "#006600" -state disabled
    puts "Written: $outPDF"
}

# Fenster anzeigen
update
wm geometry . "+50+30"

# Automatischer Export wenn -batch
if {[lsearch $argv -batch] >= 0} {
    update
    exportPDF
    destroy .
}
