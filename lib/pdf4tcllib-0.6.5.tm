# pdf4tcllib -- Extension library for pdf4tcl
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License -- see LICENSE for details
#
# Single file: all modules in one file. No external dependencies except
# pdf4tcl itself; Tk only for the image:: namespace.
#
# Modules (as namespaces):
#   pdf4tcllib::units    Unit conversion
#   pdf4tcllib::fonts    Font management (TTF + fallback)
#   pdf4tcllib::unicode  Unicode sanitization
#   pdf4tcllib::text     Text layout (wrapping, width, fitting, tabs)
#   pdf4tcllib::math     Formula rendering
#   pdf4tcllib::page     Page numbers, header/footer, context
#   pdf4tcllib::tag      Tagged PDF: elements and artifacts
#   pdf4tcllib::table    Table rendering, merged cells
#   pdf4tcllib::drawing  Shapes, gradients, arrows, callouts
#   pdf4tcllib::image    Image placement and galleries (Tk)
#   pdf4tcllib::form     Form helpers for addForm (label + field, rows)
#
# Separate packages build on this one: pdf4tcltable, pdf4tcltreeview,
# pdf4tcltext, pdf4tclforms, pdf4tcllabels, pdf4tcltoc, pdf4tclchart,
# pdf4tclflow.
#
# Requires: pdf4tcl 0.9.4.23+, Tcl 8.6+
#
# Usage:
#   package require pdf4tcllib
#   pdf4tcllib::fonts::init
#   set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
#   $pdf startPage
#   $pdf setFont 12 [pdf4tcllib::fonts::fontSans]
#   pdf4tcllib::unicode::safeText $pdf "Text" -x 50 -y 50
#   $pdf write -file out.pdf
#   $pdf destroy

package require Tcl 8.6-
package provide pdf4tcllib 0.6.5

namespace eval ::pdf4tcllib {
    # Aus package provide abgeleitet statt daneben gepflegt: die beiden
    # Zahlen liefen auseinander, weil eine von ihnen bei jedem Bump
    # vergessen wurde -- package provide stand auf 0.6.3, version auf 0.3.
    variable version [package provide pdf4tcllib]
}

proc ::pdf4tcllib::version {} {
    variable version
    return $version
}

# Tcl 8.6 compatibility shim for [dict getdef] (Tcl 8.7/9+).
# Single-key only -- no nested key path. Sufficient for internal use.
proc ::pdf4tcllib::_dictGetdef {d key default} {
    if {[dict exists $d $key]} {
        return [dict get $d $key]
    }
    return $default
}

proc ::pdf4tcllib::validate_pdf {file} {
    # Checks if a PDF file is valid.
    # Returns a dict: valid (0/1), size, error.

    if {![file exists $file]} {
        return [dict create valid 0 size 0 error "File not found"]
    }
    set size [file size $file]
    if {$size == 0} {
        return [dict create valid 0 size 0 error "File is empty"]
    }
    set fp [open $file rb]
    set header [read $fp 8]
    close $fp
    if {![string match "%PDF-*" $header]} {
        return [dict create valid 0 size $size error "Invalid PDF header"]
    }
    return [dict create valid 1 size $size error ""]
}

# ================================================================
# Module: pdf4tcllib::units
# ================================================================

# pdf4tcllib::units -- Unit conversion for pdf4tcl
#
# PDF arbeitet intern in Points (1/72 Zoll).
# This module converts between points, millimeters, centimeters and inches.
#
# Usage:
#   package require pdf4tcllib::units 0.1
#   set x [pdf4tcllib::units::mm 25.4]    ;# -> 72.0 (1 Zoll)
#   set y [pdf4tcllib::units::cm 2.54]    ;# -> 72.0
#   set m [pdf4tcllib::units::to_mm 72.0] ;# -> 25.4


namespace eval ::pdf4tcllib::units {}

proc ::pdf4tcllib::units::mm {val} {
    # Millimeter -> Points
    return [expr {$val * 72.0 / 25.4}]
}

proc ::pdf4tcllib::units::cm {val} {
    # Zentimeter -> Points
    return [expr {$val * 72.0 / 2.54}]
}

proc ::pdf4tcllib::units::inch {val} {
    # Zoll -> Points
    return [expr {$val * 72.0}]
}

proc ::pdf4tcllib::units::to_mm {pt} {
    # Points -> Millimeter
    return [expr {$pt * 25.4 / 72.0}]
}

proc ::pdf4tcllib::units::to_cm {pt} {
    # Points -> Zentimeter
    return [expr {$pt * 2.54 / 72.0}]
}

proc ::pdf4tcllib::units::to_inch {pt} {
    # Points -> Zoll
    return [expr {$pt / 72.0}]
}

# ================================================================
# Module: pdf4tcllib::fonts
# ================================================================

# pdf4tcllib::fonts -- Font management for pdf4tcl
#
# Encapsulates TTF font handling:
#   - Cross-platform font search
#   - Automatic subset construction (256 characters)
#   - Registrierung in pdf4tcl
#   - Fallback to Helvetica/Courier
#
# Usage:
#   package require pdf4tcllib::fonts 0.1
#   pdf4tcllib::fonts::init ?-fontdir /pfad? ?-family DejaVuSansCondensed?
#   set fn [pdf4tcllib::fonts::fontSans]     ;# -> "Pdf4tclSans" or "Helvetica"
#   set ok [pdf4tcllib::fonts::inSubset 8594] ;# -> 1 (Pfeil rechts)

# pdf4tcl is loaded on demand (lazy) -- not required at load time
# Call pdf4tcllib::fonts::init or use $pdf commands to trigger load.
if {[catch {package require pdf4tcl}]} {
    # pdf4tcl not yet available -- will be required when needed
}

namespace eval ::pdf4tcllib::fonts {

    # Module directory (for relative font paths)
    variable moduleDir [file dirname [file normalize [info script]]]

    # Font names (set by init)
    variable fontSans           "Helvetica"
    variable fontSansBold       "Helvetica-Bold"
    variable fontSansItalic     "Helvetica-Oblique"
    variable fontSansBoldItalic "Helvetica-BoldOblique"
    variable fontMono           "Courier"
    variable hasTtf             0
    variable hasTtfItalic       0
    variable ready              0

    # Subset-Lookup (Array: codepoint -> 1)
    variable subsetSet
    array set subsetSet {}

    # Subset list (for external query)
    variable subsetList {}

    # Width factors for fonts (factor * fontSize = average character width)
    # Etwas grosszuegiger als exakt, damit wrap/truncate sicher passen.
    variable fontWidthFactor
    array set fontWidthFactor {
        Helvetica              0.58
        Helvetica-Bold         0.64
        Helvetica-Oblique      0.58
        Helvetica-BoldOblique  0.64
        Courier                0.60
        Pdf4tclSans            0.56
        Pdf4tclSansBold        0.60
        Pdf4tclSansItalic      0.56
        Pdf4tclSansBoldItalic  0.60
    }

    # Registered font base names (for cleanup)
    variable registeredFonts {}
}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::fonts::init {args} {
    ::pdf4tcllib::_installUnicodeTitles
    # Initialize fonts. Only active on first call.
    #
    # Optionen:
    #   -fontdir  Directory with TTF fonts
    #   -family   Font family (default: DejaVuSansCondensed)
    #   -force    1 = nochmal initialisieren also if schon fertig

    variable ready
    variable moduleDir
    variable fontSans
    variable fontSansBold
    variable fontSansItalic
    variable fontSansBoldItalic
    variable fontMono
    variable hasTtf
    variable hasTtfItalic
    variable subsetSet
    variable subsetList
    variable registeredFonts

    array set opt {
        -fontdir  ""
        -family   "DejaVuSansCondensed"
        -force    0
        -cid      0
    }
    array set opt $args

    # Remember the CID mode, for the sanitize filter
    variable cidMode
    set cidMode $opt(-cid)

    if {$ready && !$opt(-force)} { return }

    # -- Search for TTF files --
    set family $opt(-family)
    set ttfRegular   ""
    set ttfBold      ""
    set ttfItalic    ""
    set ttfMono      ""
    set ttfBoldItalic ""

    set searchPaths [_buildSearchPaths $opt(-fontdir)]

    foreach dir $searchPaths {
        if {![file isdirectory $dir]} { continue }
        set tryR [file join $dir "${family}.ttf"]
        set tryB [file join $dir "${family}-Bold.ttf"]
        if {[file exists $tryR] && [file exists $tryB]} {
            set ttfRegular $tryR
            set ttfBold    $tryB
            # Optional: Oblique variants (same dir)
            set tryI  [file join $dir "${family}-Oblique.ttf"]
            set tryBI [file join $dir "${family}-BoldOblique.ttf"]
            if {[file exists $tryI]}  { set ttfItalic    $tryI }
            if {[file exists $tryBI]} { set ttfBoldItalic $tryBI }
            # Optional: a monospaced face beside the others.
            #
            # Without it fontMono stayed Courier even where TrueType was
            # loaded, and a document using it could not be PDF/A: the
            # standard 14 have no embeddable font program.
            foreach cand [list "${family}Mono.ttf" "DejaVuSansMono.ttf" \
                    "LiberationMono-Regular.ttf"] {
                set tryM [file join $dir $cand]
                if {[file exists $tryM]} { set ttfMono $tryM; break }
            }
            break
        }
    }

    if {$ttfRegular eq ""} {
        # No TTF found -> fallback
        set fontSans           "Helvetica"
        set fontSansBold       "Helvetica-Bold"
        set fontSansItalic     "Helvetica-Oblique"
        set fontSansBoldItalic "Helvetica-BoldOblique"
        set fontMono           "Courier"
        set hasTtf             0
        set hasTtfItalic       0
        set ready              1
        puts stderr "pdf4tcllib::fonts: No TTF fonts found, falling back to Helvetica"
        puts stderr "pdf4tcllib::fonts: searched in:"
        foreach dir $searchPaths {
            if {[file isdirectory $dir]} {set marker "exists"} else {set marker "---"}
            puts stderr "pdf4tcllib::fonts:   \[$marker\] $dir"
        }
        return
    }

    # -- Subset aufbauen --
    set subsetList [_buildSubset]
    array unset subsetSet
    foreach cp $subsetList {
        set subsetSet($cp) 1
    }

    # -- Register fonts in pdf4tcl --
    if {[catch {
        set existingFonts {}
        catch {set existingFonts [::pdf4tcl::getFonts]}

        # Register one font spec: depending on $cidMode either a 256
        # character encoding (small) or CID encoding (full Unicode).
        # CID buys Greek, maths symbols and arbitrary code points; it costs
        # size, because the whole TTF is embedded.
        set _registerFont [list apply {{baseName fontName cidMode subset} {
            ::pdf4tcl::loadBaseTrueTypeFont $baseName [set ::_ttfPath_$baseName]
            if {$cidMode} {
                ::pdf4tcl::createFontSpecCID $baseName $fontName
            } else {
                ::pdf4tcl::createFontSpecEnc $baseName $fontName $subset
            }
        }}]

        if {"Pdf4tclSans" ni $existingFonts} {
            ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_Regular $ttfRegular
            if {$cidMode} {
                ::pdf4tcl::createFontSpecCID _Pdf4tcl_Base_Regular Pdf4tclSans
            } else {
                ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_Regular Pdf4tclSans $subsetList
            }
            lappend registeredFonts Pdf4tclSans
        }

        if {"Pdf4tclSansBold" ni $existingFonts} {
            ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_Bold $ttfBold
            if {$cidMode} {
                ::pdf4tcl::createFontSpecCID _Pdf4tcl_Base_Bold Pdf4tclSansBold
            } else {
                ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_Bold Pdf4tclSansBold $subsetList
            }
            lappend registeredFonts Pdf4tclSansBold
        }

        set fontSans     "Pdf4tclSans"
        set fontSansBold "Pdf4tclSansBold"
        set fontMono     "Courier"
        set hasTtf       1

        # Italic TTF (optional -- Oblique variants)
        set hasTtfItalic 0
        if {$ttfItalic ne "" && $ttfBoldItalic ne ""} {
            if {[catch {
                if {"Pdf4tclSansItalic" ni $existingFonts} {
                    ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_Italic $ttfItalic
                    if {$cidMode} {
                        ::pdf4tcl::createFontSpecCID _Pdf4tcl_Base_Italic Pdf4tclSansItalic
                    } else {
                        ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_Italic Pdf4tclSansItalic $subsetList
                    }
                    lappend registeredFonts Pdf4tclSansItalic
                }
                if {"Pdf4tclSansBoldItalic" ni $existingFonts} {
                    ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_BoldItalic $ttfBoldItalic
                    if {$cidMode} {
                        ::pdf4tcl::createFontSpecCID _Pdf4tcl_Base_BoldItalic Pdf4tclSansBoldItalic
                    } else {
                        ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_BoldItalic Pdf4tclSansBoldItalic $subsetList
                    }
                    lappend registeredFonts Pdf4tclSansBoldItalic
                }
                set fontSansItalic     "Pdf4tclSansItalic"
                set fontSansBoldItalic "Pdf4tclSansBoldItalic"
                set hasTtfItalic 1
                puts stderr "pdf4tcllib::fonts: TTF italic faces loaded"
            } errI]} {
                set fontSansItalic     "Helvetica-Oblique"
                set fontSansBoldItalic "Helvetica-BoldOblique"
                puts stderr "pdf4tcllib::fonts: TTF italic error: $errI -- falling back to Helvetica-Oblique"
            }
        } else {
            set fontSansItalic     "Helvetica-Oblique"
            set fontSansBoldItalic "Helvetica-BoldOblique"
        }

        # Monospace, wenn eine Datei gefunden wurde. Schlaegt das Laden
        # fehl, bleibt Courier -- besser eine nicht einbettbare Schrift
        # als ein Abbruch beim Aufrufer.
        if {$ttfMono ne ""} {
            if {[catch {
                ::pdf4tcl::loadBaseTrueTypeFont _Pdf4tcl_Base_Mono $ttfMono
                if {$cidMode} {
                    ::pdf4tcl::createFontSpecCID _Pdf4tcl_Base_Mono Pdf4tclMono
                } else {
                    ::pdf4tcl::createFontSpecEnc _Pdf4tcl_Base_Mono Pdf4tclMono $subsetList
                }
                set fontMono "Pdf4tclMono"
            }]} {
                set fontMono "Courier"
            }
        }

        puts stderr "pdf4tcllib::fonts: TTF faces loaded from [file dirname $ttfRegular]"

    } err]} {
        set fontSans           "Helvetica"
        set fontSansBold       "Helvetica-Bold"
        set fontSansItalic     "Helvetica-Oblique"
        set fontSansBoldItalic "Helvetica-BoldOblique"
        set fontMono           "Courier"
        set hasTtf             0
        set hasTtfItalic       0
        puts stderr "pdf4tcllib::fonts: TTF error: $err"
        puts stderr "pdf4tcllib::fonts: Fallback on Helvetica"
    }

    set ready 1
}

proc ::pdf4tcllib::fonts::hasTtf {} {
    # Returns 1 if TTF fonts are loaded.
    variable hasTtf
    return $hasTtf
}

proc ::pdf4tcllib::fonts::hasTtfItalic {} {
    # Returns 1 if TTF italic fonts are loaded.
    variable hasTtfItalic
    return $hasTtfItalic
}

proc ::pdf4tcllib::fonts::isCidMode {} {
    # Returns 1 if fonts were registered with CID encoding (full Unicode),
    # 0 if classic 256-char-subset encoding was used. CID mode lifts the
    # 256-char limit -- Greek letters, Math symbols, CJK etc. all render
    # correctly, but the resulting PDF is larger (full TTF embedded).
    # Enable via:  pdf4tcllib::fonts::init -cid 1
    variable cidMode
    if {![info exists cidMode]} { return 0 }
    return $cidMode
}

proc ::pdf4tcllib::fonts::fontSans {} {
    # Returns the name of the sans-serif font.
    variable fontSans
    return $fontSans
}

proc ::pdf4tcllib::fonts::fontSansBold {} {
    # Returns the name of the bold sans-serif font.
    variable fontSansBold
    return $fontSansBold
}

proc ::pdf4tcllib::fonts::fontSansItalic {} {
    # Returns the name of the italic sans-serif font.
    variable fontSansItalic
    return $fontSansItalic
}

proc ::pdf4tcllib::fonts::fontSansBoldItalic {} {
    # Returns the name of the bold-italic sans-serif font.
    variable fontSansBoldItalic
    return $fontSansBoldItalic
}

proc ::pdf4tcllib::fonts::fontMono {} {
    # Returns the name of the monospace font.
    variable fontMono
    return $fontMono
}

proc ::pdf4tcllib::fonts::isMonospace {fontName} {
    # Checks if a font is monospace.
    variable fontMono
    return [expr {$fontName eq $fontMono || $fontName eq "Courier"}]
}

proc ::pdf4tcllib::fonts::subset {} {
    # Returns the list of codepoints in the subset.
    variable subsetList
    return $subsetList
}

proc ::pdf4tcllib::fonts::inSubset {cp} {
    # Checks if a codepoint is in the subset.
    variable subsetSet
    return [info exists subsetSet($cp)]
}

proc ::pdf4tcllib::fonts::setFont {pdf size {family Helvetica} {style ""}} {
    # Set the font from a family plus an optional style string.
    # style: "" | Bold | Italic | BoldItalic | Oblique | BoldOblique
    #
    # Maps style strings to font names:
    #   Helvetica + Bold      -> Helvetica-Bold
    #   Helvetica + Italic    -> Helvetica-Oblique
    #   Times-Roman + Bold    -> Times-Bold
    #   Courier + Italic      -> Courier-Oblique
    #
    # For TTF faces loaded via fonts::init:
    #   style Bold    -> fontSansBold
    #   style Italic  -> fontSansItalic
    #   style BoldItalic -> fontSansBoldItalic
    if {$style eq ""} {
        $pdf setFont $size $family
        return
    }

    # TTF faces, when loaded
    if {[ready]} {
        switch -- $style {
            Bold        { $pdf setFont $size [fontSansBold]; return }
            Italic      { $pdf setFont $size [fontSansItalic]; return }
            BoldItalic  { $pdf setFont $size [fontSansBoldItalic]; return }
        }
    }

    # Style mapping for the standard fonts
    set styleMap {
        Helvetica {
            Bold        Helvetica-Bold
            Italic      Helvetica-Oblique
            BoldItalic  Helvetica-BoldOblique
            Oblique     Helvetica-Oblique
            BoldOblique Helvetica-BoldOblique
        }
        Times-Roman {
            Bold        Times-Bold
            Italic      Times-Italic
            BoldItalic  Times-BoldItalic
        }
        Courier {
            Bold        Courier-Bold
            Italic      Courier-Oblique
            BoldItalic  Courier-BoldOblique
            Oblique     Courier-Oblique
            BoldOblique Courier-BoldOblique
        }
    }

    if {[dict exists $styleMap $family $style]} {
        $pdf setFont $size [dict get $styleMap $family $style]
    } else {
        # Fallback: family-style zusammensetzen
        $pdf setFont $size "${family}-${style}"
    }
}

proc ::pdf4tcllib::fonts::widthFactor {fontName} {
    # Returns the width factor for a font.
    # Factor * fontSize = average character width in points.
    variable fontWidthFactor
    if {[info exists fontWidthFactor($fontName)]} {
        return $fontWidthFactor($fontName)
    }
    return 0.52  ;# Default
}

proc ::pdf4tcllib::fonts::ready {} {
    # Returns 1 if init ausgefuehrt wurde.
    variable ready
    return $ready
}

# ============================================================
# Private Helfer
# ============================================================

proc ::pdf4tcllib::fonts::_buildSearchPaths {fontDir} {
    # Builds platform-specific list of font directories.
    variable moduleDir
    set paths {}

    # 1. Explicitly provided directory
    if {$fontDir ne "" && [file isdirectory $fontDir]} {
        lappend paths $fontDir
    }

    # 2. relative to this module
    lappend paths [file join $moduleDir .. fonts]
    lappend paths [file join $moduleDir fonts]

    # 3. Plattform-spezifisch
    switch -- $::tcl_platform(platform) {
        unix {
            # Debian/Ubuntu
            lappend paths "/usr/share/fonts/truetype/dejavu"
            # Fedora/RHEL
            lappend paths "/usr/share/fonts/dejavu-sans-fonts"
            # Arch
            lappend paths "/usr/share/fonts/TTF"
            # Generisch
            lappend paths "/usr/share/fonts/truetype"
            # User fonts
            if {[info exists ::env(HOME)]} {
                lappend paths [file join $::env(HOME) ".fonts"]
                lappend paths [file join $::env(HOME) ".local" "share" "fonts"]
            }
        }
        windows {
            if {[info exists ::env(SystemRoot)]} {
                lappend paths [file join $::env(SystemRoot) "Fonts"]
            }
            if {[info exists ::env(LOCALAPPDATA)]} {
                lappend paths [file join $::env(LOCALAPPDATA) "Microsoft" "Windows" "Fonts"]
            }
        }
    }
    # macOS (unix too, but listed separately)
    if {$::tcl_platform(os) eq "Darwin"} {
        lappend paths "/Library/Fonts"
        lappend paths "/System/Library/Fonts"
        if {[info exists ::env(HOME)]} {
            lappend paths [file join $::env(HOME) "Library" "Fonts"]
        }
    }

    return $paths
}

proc ::pdf4tcllib::fonts::_buildSubset {} {
    # Builds the 256-character subset list for createFontSpecEnc.
    #
    # Aufbau:
    #   0x00-0x7F:  ASCII (128 characters)
    #   0xA0-0xFF:  Latin-1 supplement (96 characters)
    #   Rest:       Selected symbols (32 characters)
    #
    # Gesamt: 256 = Maximum for a pdf4tcl encoding

    set subset {}

    # ASCII (0-127)
    for {set i 0} {$i < 128} {incr i} {
        lappend subset $i
    }

    # Latin-1 Supplement (0xA0-0xFF): accents, copyright, degree etc.
    for {set i 0xA0} {$i <= 0xFF} {incr i} {
        lappend subset $i
    }

    # Extended symbols, 32 of them.
    # Every value MUST be stored as an integer, not as a string.
    lappend subset [expr {0x20AC}]  ;# Euro
    lappend subset [expr {0x2013}]  ;# Halbgeviertstrich (en dash)
    lappend subset [expr {0x2014}]  ;# Geviertstrich (em dash)
    lappend subset [expr {0x2026}]  ;# Auslassungspunkte
    lappend subset [expr {0x2022}]  ;# Aufzaehlungspunkt (bullet)

    lappend subset [expr {0x2192}]  ;# Pfeil rechts
    lappend subset [expr {0x2190}]  ;# Pfeil links
    lappend subset [expr {0x2191}]  ;# Pfeil hoch
    lappend subset [expr {0x2193}]  ;# Pfeil runter

    lappend subset [expr {0x2500}]  ;# Horizontale Linie
    lappend subset [expr {0x2502}]  ;# Vertikale Linie
    lappend subset [expr {0x250C}]  ;# Ecke oben links
    lappend subset [expr {0x2510}]  ;# Ecke oben rechts
    lappend subset [expr {0x2514}]  ;# Ecke unten links
    lappend subset [expr {0x2518}]  ;# Ecke unten rechts
    lappend subset [expr {0x251C}]  ;# T links
    lappend subset [expr {0x2524}]  ;# T rechts
    lappend subset [expr {0x252C}]  ;# T oben
    lappend subset [expr {0x2534}]  ;# T unten
    lappend subset [expr {0x253C}]  ;# Kreuz

    lappend subset [expr {0x2713}]  ;# Haekchen
    lappend subset [expr {0x2717}]  ;# Kreuzchen
    lappend subset [expr {0x2611}]  ;# Checkbox angehakt
    lappend subset [expr {0x2610}]  ;# Checkbox leer

    lappend subset [expr {0x25A0}]  ;# Schwarzes Quadrat
    lappend subset [expr {0x25A1}]  ;# Weisses Quadrat
    lappend subset [expr {0x25CF}]  ;# Schwarzer Kreis
    lappend subset [expr {0x25CB}]  ;# Weisser Kreis

    lappend subset [expr {0x2264}]  ;# Kleiner gleich
    lappend subset [expr {0x2265}]  ;# Groesser gleich
    lappend subset [expr {0x2605}]  ;# Schwarzer Stern
    lappend subset [expr {0x2606}]  ;# Weisser Stern

    return $subset
}

# ================================================================
# Module: pdf4tcllib::unicode
# ================================================================

# pdf4tcllib::unicode -- Unicode sanitization for pdf4tcl
#
# Prevents crashes from characters that pdf4tcl cannot render.
# Zwei Strategien:
#   1. Replace known symbols with ASCII equivalents
#   2. Unknown characters as "?" render
#
# Usage:
#   package require pdf4tcllib::unicode 0.1
#   set clean [pdf4tcllib::unicode::sanitize $text]
#   set clean [pdf4tcllib::unicode::sanitize $text -mono 1]
#   pdf4tcllib::unicode::safeText $pdfObj $text -x 50 -y 100


namespace eval ::pdf4tcllib::unicode {
    variable _warned
    array set _warned {}

    # Wieviele Zeichen sanitize durch "?" ersetzt hat, und welche.
    #
    # Bis 0.6.3 geschah das lautlos: ein Zeichen, das die Schrift nicht
    # hat, wurde zu "?", und weder der Rueckgabewert noch ein Zaehler
    # sagte etwas. Gemessen an math::renderLatex: "\alpha \sum" ohne
    # fonts::init -cid 1 ergab sechs Fragezeichen im Inhaltsstrom, und
    # nichts wies darauf hin.
    #
    # Der Zaehler laeuft wie der von pdf4tcl (getSubstCount): kumulativ,
    # abfragbar, zuruecksetzbar. Nicht gezaehlt werden Ersetzungen, die
    # eine ABSICHT sind und nichts verlieren -- die Emoji-Umschrift
    # (U+1F600 -> ":-)") und die Kaesten der Rahmenzeichen im Base-Modus.
    # Gezaehlt wird, wo ein Zeichen verschwindet.
    variable _subst 0
    variable _substChars {}
}

# Wieviele Zeichen wurden ersetzt, seit zuletzt zurueckgesetzt wurde.
proc ::pdf4tcllib::unicode::substCount {} {
    variable _subst
    return $_subst
}

# Zaehler und Liste: {count N chars {U+03B1 U+2211 ...}}
#
# Die Liste haelt hoechstens zwoelf verschiedene Codepunkte fest -- sie
# soll sagen, WAS fehlt, nicht jedes Vorkommen protokollieren.
proc ::pdf4tcllib::unicode::substReport {} {
    variable _subst
    variable _substChars
    return [dict create count $_subst chars $_substChars]
}

proc ::pdf4tcllib::unicode::resetSubst {} {
    variable _subst
    variable _substChars
    set _subst 0
    set _substChars {}
    return
}

# Eine Ersetzung vermerken.
proc ::pdf4tcllib::unicode::_countSubst {cp} {
    variable _subst
    variable _substChars
    incr _subst
    set name [format "U+%04X" $cp]
    if {[lsearch -exact $_substChars $name] < 0 &&
            [llength $_substChars] < 12} {
        lappend _substChars $name
    }
    # Einmal je Sitzung laut werden -- der Zaehler allein hilft nur dem,
    # der ihn abfragt.
    _warnOnce subst "sanitize: at least one character is missing from the\
 font and was replaced with '?' (first: $name). Ask\
 ::pdf4tcllib::unicode::substReport for the list, or load a font that has\
 it -- fonts::init -cid 1 for Greek and mathematical symbols."
    return
}

# One-time warning to stderr (deduplicated by key) so a catch-based fallback
# does not hide that characters were substituted or dropped.
proc ::pdf4tcllib::unicode::_warnOnce {key msg} {
    variable _warned
    if {[info exists _warned($key)]} { return }
    set _warned($key) 1
    puts stderr "pdf4tcllib::unicode: $msg"
}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::unicode::sanitize {line args} {
    # Replaces/removes Unicode characters that the current font
    # not darstellbar sind.
    #
    # Optionen:
    #   -mono 0/1   Monospace mode (Courier): always ASCII replacement
    #
    # Zwei Modi:
    #   TTF-Modus (hasTtf=1, mono=0):
    #     Subset characters native, map variants to subset,
    #     unbekannte -> "?"
    #   Base-Modus (hasTtf=0 or mono=1):
    #     Replace all symbols > U+00FF with ASCII,
    #     only WinAnsi-Bereich durchlassen

    array set opt {-mono 0}
    array set opt $args

    set hasTtf [::pdf4tcllib::fonts::hasTtf]
    set effectiveTtf [expr {$hasTtf && !$opt(-mono)}]

    # -- Stage 1: Replace known symbols --

    if {!$effectiveTtf} {
        # Base mode: replace everything that doesn't fit WinAnsi

        # Box-drawing characters
        set line [string map {
            "\u2500" "-"
            "\u2501" "-"
            "\u2502" "|"
            "\u2503" "|"
            "\u250C" "+"
            "\u2510" "+"
            "\u2514" "+"
            "\u2518" "+"
            "\u251C" "|"
            "\u2524" "|"
            "\u252C" "+"
            "\u2534" "+"
            "\u253C" "+"
        } $line]

        # Haeufige Unicode-Symbole
        set line [string map {
            "\u2192" "->"
            "\u2190" "<-"
            "\u2191" "^"
            "\u2193" "v"
            "\u2022" "*"
            "\u00B7" "."
            "\u2026" "..."
            "\u2014" "--"
            "\u2013" "-"
            "\u2713" "[x]"
            "\u2717" "[ ]"
            "\u2611" "[x]"
            "\u2610" "[ ]"
            "\u2605" "*"
            "\u2606" "*"
            "\u25B6" ">"
            "\u25C0" "<"
            "\u25BA" ">"
            "\u25C4" "<"
            "\u25CF" "o"
            "\u25CB" "o"
            "\u25A0" "#"
            "\u25A1" "#"
            "\u25AA" "-"
            "\u25AB" "-"
        } $line]

        # Common emojis and special characters
        set line [string map {
            "\u274C" "(X)"
            "\u274E" "(X)"
            "\u2705" "(OK)"
            "\u2714" "(OK)"
            "\u26A0" "(!)"
            "\u2757" "(!)"
            "\u2753" "(?)"
            "\u2139" "(i)"
            "\u27A1" "->"
            "\u2B05" "<-"
            "\u2B06" "^"
            "\u2B07" "v"
            "\u2764" "<3"
            "\u2728" "*"
            "\u26A1" "*"
            "\u2699" "[*]"
            "\u267B" "[R]"
            "\u00A9" "(c)"
            "\u00AE" "(R)"
            "\u2122" "(TM)"
            "\u20AC" "EUR"
            "\u201E" "\""
            "\u201C" "\""
            "\u201D" "\""
            "\u201A" "'"
            "\u2018" "'"
            "\u2019" "'"
        } $line]
    } else {
        # TTF-Modus: Nur Varianten on Subset-Zeichen mappen.
        # character im Subset werden nativ dargestellt.

        set line [string map {
            "\u2501" "\u2500"
            "\u2503" "\u2502"
            "\u25BA" ">"
            "\u25C4" "<"
            "\u25AA" "\u25A0"
            "\u25AB" "\u25A1"
            "\u274C" "(X)"
            "\u274E" "(X)"
            "\u2705" "\u2713"
            "\u2714" "\u2713"
            "\u2757" "(!)"
            "\u2753" "(?)"
            "\u2139" "(i)"
            "\u27A1" "\u2192"
            "\u2B05" "\u2190"
            "\u2B06" "\u2191"
            "\u2B07" "\u2193"
            "\u2764" "<3"
            "\u2728" "\u2605"
            "\u26A0" "(!)"
            "\u26A1" "\u2605"
            "\u2699" "[*]"
            "\u267B" "[R]"
            "\u2122" "(TM)"
            "\u201E" "\""
            "\u201C" "\""
            "\u201D" "\""
            "\u201A" "'"
            "\u2018" "'"
            "\u2019" "'"
        } $line]
    }

    # -- Stage 2: Catch-All --
    # Check each character individually.
    # Only pass through characters the active font can render.
    # Surrogate-Paare (Tcl 8.6, TCL_UTF_MAX=3) werden als Emoji erkannt.

    set result ""
    set chars [split $line ""]
    set len [llength $chars]
    for {set i 0} {$i < $len} {incr i} {
        set c [lindex $chars $i]
        set cp [scan $c %c]

        # Unsichtbare Steuerzeichen entfernen
        if {($cp >= 0xFE00 && $cp <= 0xFE0F) ||
            ($cp >= 0x200B && $cp <= 0x200F) ||
            $cp == 0xFEFF} {
            continue
        }

        # Detect a surrogate pair (Tcl 8.6 emoji handling)
        if {$cp >= 0xD800 && $cp <= 0xDBFF} {
            # High surrogate -- look for the low surrogate next
            set j [expr {$i + 1}]
            if {$j < $len} {
                set c2 [lindex $chars $j]
                set cp2 [scan $c2 %c]
                if {$cp2 >= 0xDC00 && $cp2 <= 0xDFFF} {
                    # Gueltige Surrogate-Pair -> echten Codepoint berechnen
                    set fullCp [expr {(($cp - 0xD800) << 10) + ($cp2 - 0xDC00) + 0x10000}]
                    append result [::pdf4tcllib::unicode::_emojiFallback $fullCp]
                    incr i  ;# Low surrogate ueberspringen
                    continue
                }
            }
            # Single high surrogate -> skip
            continue
        } elseif {$cp >= 0xDC00 && $cp <= 0xDFFF} {
            # Single low surrogate -> skip
            continue
        }

        if {$effectiveTtf} {
            # U+FFFD: Tcl 8.6 hat ein Emoji zerstoert.
            # Kann not mehr rekonstruiert werden.
            # Tipp: preprocessBytes vor encoding convertfrom verwenden.
            if {$cp == 0xFFFD} {
                append result "(?)"
                continue
            }
            # Nicht-BMP character (TCL_UTF_MAX=4: direkte Codepoints > 0xFFFF)
            # Bei TCL_UTF_MAX=3 kommen diese als Surrogate-Paare (oben behandelt)
            if {$cp > 0xFFFF} {
                append result [::pdf4tcllib::unicode::_emojiFallback $cp]
                continue
            }
            # TTF mode: the subset filter applies to the classic 256
            # character encoding only. In CID mode (full Unicode)
            # everything passes -- pdf4tcl does the glyph lookup and maps
            # unknown code points to .notdef itself.
            if {[::pdf4tcllib::fonts::isCidMode]} {
                append result $c
            } elseif {[::pdf4tcllib::fonts::inSubset $cp]} {
                append result $c
            } else {
                _countSubst $cp
                append result "?"
            }
        } else {
            # U+FFFD also im Base-Modus abfangen
            if {$cp == 0xFFFD} {
                append result "(?)"
                continue
            }
            # Nicht-BMP character also im Base-Modus abfangen
            if {$cp > 0xFFFF} {
                append result [::pdf4tcllib::unicode::_emojiFallback $cp]
                continue
            }
            # Base-Modus (WinAnsiEncoding):
            # ASCII druckbar (0x20-0x7E) + Latin-1 Supplement (0xA0-0xFF)
            if {($cp >= 0x20 && $cp <= 0x7E) ||
                ($cp >= 0xA0 && $cp <= 0xFF)} {
                append result $c
            } elseif {$cp == 0x09 || $cp == 0x0A || $cp == 0x0D} {
                # Tab, Newline, CR
                append result $c
            } else {
                _countSubst $cp
                append result "?"
            }
        }
    }

    return $result
}

proc ::pdf4tcllib::unicode::_emojiFallback {cp} {
    # Returns ASCII fallback for an emoji codepoint.
    # Wird aufgerufen if Surrogate-Paare in Tcl 8.6 erkannt werden.

    # Spezifische Mappings (haeufigste Emojis)
    switch -exact -- $cp {
        128512 { return ":-)" }
        128513 { return ":-D" }
        128514 { return ":'D" }
        128515 { return ":-D" }
        128516 { return ":-D" }
        128521 { return ";-)" }
        128522 { return ":-)" }
        128525 { return "<3" }
        128526 { return "B-)" }
        128536 { return ":-*" }
        128540 { return ":-P" }
        128542 { return ":-(" }
        128546 { return ":-(" }
        128557 { return ":'(" }
        128558 { return ":-O" }
        128561 { return ":-O" }
        128563 { return ":-/" }
        128566 { return ":-|" }
        128567 { return ":-|" }
        128568 { return ":-)" }
        128580 { return ":-/" }
        129300 { return "(?)" }
        129315 { return ":'D" }
        127881 { return "(!)" }
        127882 { return "(!)" }
        128077 { return "(+1)" }
        128078 { return "(-1)" }
        128075 { return "(*)" }
        128293 { return "(*)" }
        128161 { return "(!)" }
        128640 { return {[>]} }
        128175 { return "(100)" }
        128591 { return "(*)" }
        128170 { return "(*)" }
        128193 { return {[D]} }
        128196 { return {[doc]} }
        128221 { return {[doc]} }
        128231 { return {[@]} }
        128274 { return {[L]} }
        128275 { return {[U]} }
        10024  { return "*" }
        9989   { return "(OK)" }
    }

    # Range-basierte Fallbacks
    if {$cp >= 0x1F600 && $cp <= 0x1F64F} { return ":-)" }
    if {$cp >= 0x1F380 && $cp <= 0x1F3FF} { return "(!)" }
    if {$cp >= 0x1F440 && $cp <= 0x1F4FF} { return "(*)" }
    if {$cp >= 0x1F500 && $cp <= 0x1F5FF} { return "(*)" }
    if {$cp >= 0x1F680 && $cp <= 0x1F6FF} { return {[>]} }
    if {$cp >= 0x1F900 && $cp <= 0x1F9FF} { return ":-)" }
    if {$cp >= 0x1FA00 && $cp <= 0x1FAFF} { return "(*)" }

    return "(?)"
}

proc ::pdf4tcllib::unicode::preprocessBytes {data} {
    # Replaces 4-byte UTF-8 sequences (emoji, beyond the BMP) with ASCII
    # fallbacks.
    #
    # MUST be called on BINARY data, BEFORE Tcl converts the bytes into its
    # internal string representation (encoding convertfrom).
    #
    # Tcl 8.6 cannot represent code points above U+FFFF and turns them into
    # U+FFFD. This catches the raw UTF-8 bytes before that happens.
    #
    # Usage:
    #   set f [open $file rb]
    #   set raw [read $f]; close $f
    #   set clean [::pdf4tcllib::unicode::preprocessBytes $raw]
    #   set text [encoding convertfrom utf-8 $clean]

    set result {}
    set len [string length $data]
    set i 0

    while {$i < $len} {
        set byte [scan [string index $data $i] %c]

        # 4-Byte UTF-8: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
        if {($byte & 0xF8) == 0xF0 && ($i + 3) < $len} {
            set b2 [scan [string index $data [expr {$i+1}]] %c]
            set b3 [scan [string index $data [expr {$i+2}]] %c]
            set b4 [scan [string index $data [expr {$i+3}]] %c]

            if {($b2 & 0xC0) == 0x80 && ($b3 & 0xC0) == 0x80 && ($b4 & 0xC0) == 0x80} {
                set cp [expr {(($byte & 0x07) << 18) | (($b2 & 0x3F) << 12) | (($b3 & 0x3F) << 6) | ($b4 & 0x3F)}]
                append result [::pdf4tcllib::unicode::_emojiFallback $cp]
                incr i 4
                continue
            }
        }

        append result [string index $data $i]
        incr i
    }

    return $result
}

proc ::pdf4tcllib::unicode::readFile {filename} {
    # Reads a UTF-8 file with emoji preprocessing.
    # Returns a clean Tcl string.
    set f [open $filename rb]
    set raw [read $f]
    close $f
    set clean [::pdf4tcllib::unicode::preprocessBytes $raw]
    return [encoding convertfrom utf-8 $clean]
}

proc ::pdf4tcllib::unicode::safeText {pdf txt args} {
    # Write text through pdf4tcl safely: sanitize it and catch errors.
    #
    # Arguments:
    #   pdf   - the pdf4tcl object
    #   txt   - the text to write
    #   args  - passed on to `$pdf text` (-x, -y, -align, ...)
    #
    # Optional:
    #   -mono 0/1   taken out of args and passed to sanitize

    # -mono extrahieren falls vorhanden
    set mono 0
    set passArgs {}
    set i 0
    foreach {k v} $args {
        if {$k eq "-mono"} {
            set mono $v
        } else {
            lappend passArgs $k $v
        }
    }

    set clean [sanitize $txt -mono $mono]

    # Ein Loch im Strukturbaum, wenn niemand ausgezeichnet hat.
    #
    # safeText ist eine oeffentliche Zeichenprozedur, und sie liess bis
    # 0.6.3 einen ungetaggten Zeichenbefehl stehen -- gemessen mit
    # getUntaggedCount 1 nach einem einzigen Aufruf. Dieselbe Klasse wie
    # die Formularbeschriftungen, der Text-Widget-Export und die Pfeile,
    # die in dieser Sitzung schon geschlossen wurden. Gefunden hat es
    # eine Demo, die sich selbst prueft.
    #
    # Ausgezeichnet wird NUR, wenn kein Element offen ist. Sonst
    # schachtelte ein P in ein P, sobald ein Aufrufer -- table::draw,
    # forms:: oder math::_pdfBackend -- schon ausgezeichnet hat. Genau
    # dafuer gibt es tag::depth.
    set selbstTaggen [expr {[::pdf4tcllib::tag::isActive $pdf]
            && [::pdf4tcllib::tag::depth $pdf] == 0}]
    if {$selbstTaggen} { ::pdf4tcllib::tag::begin $pdf Span }

    if {[catch {$pdf text $clean {*}$passArgs} err]} {
        # Notfall: Alles on druckbares ASCII reduzieren. Das ersetzt Zeichen,
        # daher sichtbar machen statt Glyphen still zu verlieren.
        _warnOnce safeText-fallback "safeText: '\$pdf text' failed ($err);\
 falling back to ASCII (non-ASCII characters replaced with '?')"
        set safe ""
        foreach c [split $clean ""] {
            set cp [scan $c %c]
            if {($cp >= 0x20 && $cp <= 0x7E) ||
                $cp == 0x09 || $cp == 0x0A || $cp == 0x0D} {
                append safe $c
            } else {
                append safe "?"
            }
        }
        if {[catch {$pdf text $safe {*}$passArgs} err2]} {
            # even the ASCII fallback failed -> nothing was drawn; surface it
            _warnOnce safeText-failed "safeText: ASCII fallback also failed\
 ($err2); text was not drawn"
        }
    }
    if {$selbstTaggen} { ::pdf4tcllib::tag::end $pdf }
}

# ================================================================
# Module: pdf4tcllib::text
# ================================================================

# pdf4tcllib::text -- Text-Layout for pdf4tcl
#
# linesumbruch, widthnmessung, Tab-Expansion.
# Arbeitet with den Fonts from pdf4tcllib::fonts.
#
# Usage:
#   package require pdf4tcllib::text 0.1
#   set lines [pdf4tcllib::text::wrap $text $maxW $fontSize $fontName]
#   set w [pdf4tcllib::text::width $text $fontSize $fontName]


namespace eval ::pdf4tcllib::text {}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::text::width {text fontSize fontName {pdf {}}} {
    # Returns the width of text in points.
    #
    # If pdf is given (pdf4tcl object, 0.9.4.23+): uses exact font metrics
    # via getStringWidth -font -size. No prior setFont needed.
    #
    # Fallback (no pdf or old pdf4tcl): character class estimation.

    # Try exact metrics via pdf4tcl 0.9.4.23+ API
    if {$pdf ne {} && ![catch {
        $pdf getStringWidth $text -font $fontName -size $fontSize -internal 1
    } w]} {
        return $w
    }

    # Fallback: character class estimation (pre-0.9.4.23 or no pdf object)
    set factor [::pdf4tcllib::fonts::widthFactor $fontName]
    set isCode [::pdf4tcllib::fonts::isMonospace $fontName]

    if {$isCode} {
        return [expr {[string length $text] * $fontSize * $factor}]
    }

    set len 0.0
    foreach c [split $text ""] {
        switch -exact -- $c {
            "i" - "l" - "j" - "f" - "t" - "r" {
                set len [expr {$len + 0.55}]
            }
            "." - "," - ":" - ";" - "!" - "|" - "'" - " " {
                set len [expr {$len + 0.40}]
            }
            "m" - "w" {
                set len [expr {$len + 1.35}]
            }
            "M" - "W" {
                set len [expr {$len + 1.45}]
            }
            "A" - "B" - "C" - "D" - "G" - "H" - "K" - "N" - "O" - "P" - "Q" - "R" - "U" - "V" - "X" - "Y" - "Z" {
                set len [expr {$len + 1.15}]
            }
            "0" - "1" - "2" - "3" - "4" - "5" - "6" - "7" - "8" - "9" {
                set len [expr {$len + 1.0}]
            }
            default {
                set len [expr {$len + 1.0}]
            }
        }
    }
    return [expr {$len * $fontSize * $factor}]
}

# Ein Wort in Stuecke zerlegen, an denen umbrochen werden darf.
#
# Der Trenner bleibt am ENDE des vorigen Stuecks: "Muster-" sagt dem
# Leser, dass es weitergeht -- ohne ihn liest sich die Zeile wie ein
# vollstaendiges Wort.
#
# EIN Strich trennt nur zwischen zwei Zeichen, nicht am Wortanfang: sonst
# wuerde "-5 Euro" zu "-" und "5 Euro". Genau diese Regel hat pdf4tcl in
# drawTextBox seit 0.9.4.60, und beide muessen dieselbe haben -- sonst
# bricht derselbe Text im Kern anders um als in der Bibliothek.
proc ::pdf4tcllib::text::_stuecke {wort trenner} {
    if {![llength $trenner]} { return [list $wort] }
    set out {}
    set rest $wort
    set weiter 1
    while {$weiter} {
        set weiter 0
        # Den fruehesten Trenner suchen, der weder am Anfang noch am Ende
        # steht und auf ein Buchstaben- oder Ziffernzeichen folgt.
        set beste -1
        foreach z $trenner {
            set von 1
            while {1} {
                set i [string first $z $rest $von]
                if {$i < 0 || $i >= [string length $rest] - 1} { break }
                if {[string is alnum -strict [string index $rest [expr {$i - 1}]]]} {
                    if {$beste < 0 || $i < $beste} { set beste $i }
                    break
                }
                set von [expr {$i + 1}]
            }
        }
        if {$beste >= 0} {
            lappend out [string range $rest 0 $beste]
            set rest [string range $rest [expr {$beste + 1}] end]
            set weiter 1
        }
    }
    if {$rest ne ""} { lappend out $rest }
    if {![llength $out]} { set out [list $wort] }
    return $out
}

proc ::pdf4tcllib::text::_endetAufTrenner {s trenner} {
    foreach z $trenner {
        if {[string index $s end] eq $z} { return 1 }
    }
    return 0
}

proc ::pdf4tcllib::text::_hardBreak {word maxW fontSize fontName {pdf {}}} {
    # Greedily splits a single over-wide word into pieces that each fit maxW.
    # Always emits at least one character per piece, so a single glyph wider
    # than the column cannot loop forever. Used by wrap when hardBreak is on,
    # so long space-less tokens (paths, dotted names) survive instead of being
    # truncated.
    set pieces {}
    set cur ""
    foreach ch [split $word ""] {
        set cand "$cur$ch"
        if {$cur eq "" || [width $cand $fontSize $fontName $pdf] <= $maxW} {
            set cur $cand
        } else {
            lappend pieces $cur
            set cur $ch
        }
    }
    if {$cur ne ""} { lappend pieces $cur }
    if {[llength $pieces] == 0} { set pieces [list ""] }
    return $pieces
}

proc ::pdf4tcllib::text::wrap {line maxW fontSize fontName {codeContinuation 0} {pdf {}} {hardBreak 0} {trenner {- /}}} {
    # Wraps a line at word boundaries, and inside a word at a hyphen or
    # slash between two characters.
    #
    # Returns a list of sub-lines that each fit within maxW.
    # hardBreak 0 (default): over-wide words are truncated (unchanged legacy
    #   behaviour). hardBreak 1: over-wide words are broken character-wise so
    #   nothing is lost (needed for table cells with long path/dotted tokens).
    #
    # codeContinuation: if 1, a wrapped code line is marked with a
    # trailing " \\", Tcl style.
    #
    # trenner: the characters a word may additionally break at. Up to
    # 0.6.2 there were none, so "Muster-Beispiel-Stadt" was cut
    # character-wise in a narrow column -- "Muster-Beispi" / "el-Stadt",
    # with no hyphen to show it continues. pdf4tcl breaks at the hyphen in
    # drawTextBox since 0.9.4.60, and the two have to agree: otherwise the
    # same string comes out differently depending on which of them drew
    # it. Pass {} for the old behaviour.
    #
    # The measurement takes $pdf everywhere. It used to be passed at ONE
    # of four places, so the other three fell back to the character-class
    # estimate -- which does not know the font. Measured with DejaVu Sans
    # as a CID font, "w35 Mo 17.08.26 CC Sped1" at size 8: 110.73 points
    # exact against 89.44 estimated. A table in a CID font therefore broke
    # in the wrong place.

    if {[width $line $fontSize $fontName $pdf] <= $maxW} {
        return [list $line]
    }

    # Bei Code-Continuation Platz for " \" reservieren
    if {$codeContinuation} {
        set wrapMaxW [expr {$maxW - [width " \\" $fontSize $fontName $pdf]}]
    } else {
        set wrapMaxW $maxW
    }

    # Jedes Wort in Stuecke, an denen umbrochen werden darf. Ohne Trenner
    # ist das Stueck das Wort, und die Schleife arbeitet wie zuvor.
    set words {}
    foreach wort [split $line " "] {
        foreach st [_stuecke $wort $trenner] { lappend words $st }
    }
    set lines {}
    set current ""

    foreach word $words {
        if {$current eq ""} {
            set test $word
        } elseif {[_endetAufTrenner $current $trenner]} {
            # Nach einem Trenner KEIN Leerzeichen: "Muster-" und
            # "Beispiel" gehoeren zusammen, wenn beides in eine Zeile
            # passt.
            set test "$current$word"
        } else {
            set test "$current $word"
        }

        if {[width $test $fontSize $fontName $pdf] <= $wrapMaxW} {
            set current $test
        } else {
            if {$current ne ""} {
                lappend lines $current
            }
            # Check word alone
            if {[width $word $fontSize $fontName $pdf] > $wrapMaxW} {
                if {$hardBreak} {
                    # break char-wise; flush all but the last piece as full
                    # lines, keep the last as the running line so following
                    # words may still join it.
                    set pieces [_hardBreak $word $wrapMaxW $fontSize $fontName $pdf]
                    foreach p [lrange $pieces 0 end-1] { lappend lines $p }
                    set current [lindex $pieces end]
                } else {
                    set current [truncate $word $wrapMaxW $fontSize $fontName $pdf]
                }
            } else {
                set current $word
            }
        }
    }

    if {$current ne ""} {
        lappend lines $current
    }

    if {[llength $lines] == 0} {
        return [list $line]
    }

    # Code continuation: append backslash to all lines except last
    if {$codeContinuation && [llength $lines] > 1} {
        set result {}
        set lastIdx [expr {[llength $lines] - 1}]
        for {set i 0} {$i < [llength $lines]} {incr i} {
            if {$i < $lastIdx} {
                lappend result "[lindex $lines $i] \\"
            } else {
                lappend result [lindex $lines $i]
            }
        }
        return $result
    }

    return $lines
}

proc ::pdf4tcllib::text::truncate {text maxW fontSize fontName {pdf {}}} {
    # Truncates text if wider than maxW. Adds "..." at end.
    # pdf (optional): pdf4tcl object for exact metrics (0.9.4.23+).

    if {[width $text $fontSize $fontName $pdf] <= $maxW} {
        return $text
    }

    set lo 0
    set hi [string length $text]
    while {$lo < $hi} {
        set mid [expr {($lo + $hi + 1) / 2}]
        set try "[string range $text 0 $mid-1]..."
        if {[width $try $fontSize $fontName $pdf] <= $maxW} {
            set lo $mid
        } else {
            set hi [expr {$mid - 1}]
        }
    }

    if {$lo == 0} { return "..." }
    return "[string range $text 0 $lo-1]..."
}

# Die groesste Schriftgroesse, bei der der Text noch in maxW passt.
#
# truncate schneidet ab, und manchmal ist genau das falsch: "Sped1" und
# "Sped2" unterscheiden sich am letzten Zeichen, und ein gekuerzter Beleg
# schickt den Fahrer auf die andere Tour. Dasselbe bei Kundennamen zweier
# Betriebe derselben Familie und bei Zahlen mit Nachkommastellen -- 12.12
# gekuerzt ist 12.1, und das gibt es auch.
#
# -min: kleiner wird nicht gesetzt, Vorgabe 6. Passt es auch dort nicht,
# kommt -min zurueck; der Aufrufer entscheidet dann, ob er ueberstehen
# laesst oder doch kuerzt. Ein Text, den niemand lesen kann, hilft auch
# nicht. Liegt -min ueber der Wunschgroesse, gilt die Wunschgroesse --
# sonst kaeme eine GROESSERE Schrift zurueck, als verlangt war.
#
# -pdf: bei einer CID-Schrift nicht weglassen. Ohne das Objekt schaetzt
# width ueber Zeichenklassen; gemessen an DejaVu Sans, Groesse 8: 110.73
# Punkt exakt gegen 89.44 geschaetzt. Die Schaetzung haelt fuer passend,
# was 20 Punkt uebersteht.
proc ::pdf4tcllib::text::fitSize {text maxW wunschGroesse fontName args} {
    array set opt {-min 6 -pdf {}}
    foreach {k v} $args {
        if {![info exists opt($k)]} {
            return -code error "text::fitSize: unknown option $k\
                    (known: [join [lsort [array names opt]] { }])"
        }
        set opt($k) $v
    }
    if {$text eq "" || $maxW <= 0} { return $wunschGroesse }
    if {$opt(-min) > $wunschGroesse} { set opt(-min) $wunschGroesse }
    for {set g $wunschGroesse} {$g > $opt(-min)} {incr g -1} {
        if {[width $text $g $fontName $opt(-pdf)] <= $maxW} { return $g }
    }
    return $opt(-min)
}

# Passt der Text bei dieser Groesse? width und Vergleich in einem.
proc ::pdf4tcllib::text::fits {text maxW fontSize fontName {pdf {}}} {
    return [expr {[width $text $fontSize $fontName $pdf] <= $maxW}]
}

proc ::pdf4tcllib::text::expandTabs {line {tabWidth 4}} {
    # Expandiert Tabs zu Leerzeichen.
    #
    # Each tab is replaced with enough spaces to reach the next
    # Tab-Position zu erreichen.

    set result ""
    set col 0
    foreach c [split $line ""] {
        if {$c eq "\t"} {
            set spaces [expr {$tabWidth - ($col % $tabWidth)}]
            append result [string repeat " " $spaces]
            incr col $spaces
        } else {
            append result $c
            incr col
        }
    }
    return $result
}

proc ::pdf4tcllib::text::detectFont {line} {
    # Detects if a line has monospace formatting.
    #
    # Returns den passenden Font-Namen from pdf4tcllib::fonts.
    # Kriterien for Monospace:
    #   - line beginnt with Tab
    #   - line starts with 4+ spaces (code indentation)
    #   - line enthaelt Tcl-Syntax ($var, ::, ->)

    if {[string first "\t" $line] >= 0} {
        return [::pdf4tcllib::fonts::fontMono]
    }
    if {[regexp {^    } $line]} {
        return [::pdf4tcllib::fonts::fontMono]
    }
    if {[regexp {^\s*\|} $line]} {
        return [::pdf4tcllib::fonts::fontMono]
    }
    if {[regexp {\$\w+|::|->|\{.*\}} $line]} {
        return [::pdf4tcllib::fonts::fontMono]
    }
    return [::pdf4tcllib::fonts::fontSans]
}

proc ::pdf4tcllib::text::writeParagraph {pdf text x y width {size 12} {align left} {tag P}} {
    # Writes a paragraph with automatic line wrapping.
    # Returns the next Y position after the last rendered line.
    #
    # Uses drawTextBox -newyvar (pdf4tcl 0.9.4.23+) for exact Y position.
    # Fallback: line count estimation for older pdf4tcl.
    #
    # tag  structure type the text is wrapped in, P by default. Pass H1..H6
    #      for a heading, Caption for a caption, or "" to write nothing --
    #      the last one leaves content outside the structure tree, which
    #      pdf4tcl 0.9.4.43 counts and reports at finish.
    #
    # The default is what makes this safe to keep calling: existing code
    # gets a P where it used to get nothing at all. Worth knowing when a
    # caller uses this procedure to set a heading -- it will be marked up
    # as body text unless the tag is given.

    $pdf setFont $size [::pdf4tcllib::_defaultFamily]
    if {$tag ne ""} { ::pdf4tcllib::tag::begin $pdf $tag }

    # The returned y is counted from the LINE COUNT, not from -newyvar.
    #
    # -newyvar looked like the exact answer and is not: measured
    # 2026-08-15 with pdf4tcl 0.9.4.43, it reports the position from the
    # BOTTOM of the page while the y passed in counts from the top, so
    # under orient 1 -- what page::context assumes -- a paragraph starting
    # at y=200 came back as 633.5 instead of 208.4. Under orient 0 the
    # 10000 pt box height leaked into the result (10191.5). Nobody noticed
    # because no caller in the tree used the return value; the
    # documentation has promised "the next Y position" all along.
    #
    # -linesvar is orientation-free and says what was actually laid out:
    # one line for empty text, six for a paragraph of six lines.
    set lh [::pdf4tcllib::page::lineheight $size]
    set lines_var ::pdf4tcllib::text::_temp_lines
    set $lines_var 0
    $pdf drawTextBox $x $y $width 10000 $text \
        -align $align \
        -linesvar $lines_var

    set num_lines [set $lines_var]
    if {![string is integer -strict $num_lines] || $num_lines < 1} {
        # Older pdf4tcl without -linesvar: estimate rather than return
        # something that is certainly wrong.
        set num_lines [expr {[string length $text] / 50 + 1}]
    }
    if {$tag ne ""} { ::pdf4tcllib::tag::end $pdf }
    # y grows downwards under orient 1 (the pdf4tcl default and what
    # page::context assumes) and upwards under orient 0.
    set orient 1
    catch {set orient [$pdf cget -orient]}
    if {$orient} {
        return [expr {$y + $num_lines * $lh}]
    }
    return [expr {$y - $num_lines * $lh}]
}


# ----------------------------------------------------------------
# Inline maths helpers -- a subset, not a full LaTeX
# ----------------------------------------------------------------
# A pragmatic approach: sub- and superscript through a y offset plus a
# reduced font size, and a lookup table from common LaTeX symbol names to
# Unicode.
#
# That covers inline maths such as $x^2$, $H_2O$, $\alpha + \beta$ straight
# into the PDF. Anything larger -- fractions, roots, integral limits --
# needs an external renderer (KaTeX CLI -> SVG, embedded as an image).
#
# pdf4tcl text conventions:
#   $pdf text $str -x $x -y $y -font $font
# y is the baseline. For a superscript we move up, and since y runs
# top-down in pdf4tcl, moving up means subtracting from y.

proc ::pdf4tcllib::text::superscript {pdf textStr x y fontSize fontName} {
    # Draw textStr as a superscript: font size down to 70%, baseline
    # shifted up by 35% of the original size. Returns the width of the
    # text drawn, for the caller's x advance.
    set smallSize [expr {$fontSize * 0.7}]
    set yShift    [expr {$fontSize * 0.35}]
    set ySuper    [expr {$y - $yShift}]
    $pdf setFont $smallSize $fontName
    $pdf text $textStr -x $x -y $ySuper
    set w [$pdf getStringWidth $textStr]
    # Restore the font; a caller expecting otherwise has to say so
    $pdf setFont $fontSize $fontName
    return $w
}

proc ::pdf4tcllib::text::subscript {pdf textStr x y fontSize fontName} {
    # Tiefstellung: gleicher Mechanismus, y-Shift NACH UNTEN.
    set smallSize [expr {$fontSize * 0.7}]
    set yShift    [expr {$fontSize * 0.20}]
    set ySub      [expr {$y + $yShift}]
    $pdf setFont $smallSize $fontName
    $pdf text $textStr -x $x -y $ySub
    set w [$pdf getStringWidth $textStr]
    $pdf setFont $fontSize $fontName
    return $w
}

# LaTeX-Symbol-Name -> Unicode-Zeichen
# A subset of the most common maths symbols. Extend as needed.
variable ::pdf4tcllib::text::_mathSymbols {
    alpha    \u03B1   beta     \u03B2   gamma    \u03B3   delta    \u03B4
    epsilon  \u03B5   zeta     \u03B6   eta      \u03B7   theta    \u03B8
    iota     \u03B9   kappa    \u03BA   lambda   \u03BB   mu       \u03BC
    nu       \u03BD   xi       \u03BE   omicron  \u03BF   pi       \u03C0
    rho      \u03C1   sigma    \u03C3   tau      \u03C4   upsilon  \u03C5
    phi      \u03C6   chi      \u03C7   psi      \u03C8   omega    \u03C9
    Alpha    \u0391   Beta     \u0392   Gamma    \u0393   Delta    \u0394
    Theta    \u0398   Lambda   \u039B   Pi       \u03A0   Sigma    \u03A3
    Phi      \u03A6   Psi      \u03A8   Omega    \u03A9
    infty    \u221E   sum      \u2211   prod     \u220F   int      \u222B
    partial  \u2202   nabla    \u2207   sqrt     \u221A
    le       \u2264   ge       \u2265   ne       \u2260   approx   \u2248
    equiv    \u2261   pm       \u00B1   mp       \u2213   times    \u00D7
    cdot     \u00B7   div      \u00F7   to       \u2192   gets     \u2190
    Rightarrow \u21D2 Leftarrow \u21D0  rightarrow \u2192   leftarrow \u2190
    in       \u2208   notin    \u2209
    subset   \u2282   supset   \u2283   cup      \u222A   cap      \u2229
    emptyset \u2205   forall   \u2200   exists   \u2203
    deg      \u00B0   prime    \u2032
}

proc ::pdf4tcllib::text::mathSymbol {name} {
    # The Unicode character for a LaTeX symbol name.
    # Examples:
    #   text::mathSymbol alpha   -> \u03B1
    #   text::mathSymbol cdot    -> \u00B7
    #   text::mathSymbol unknown -> "" (no error, so the caller can
    #                                   simply render a fallback)
    variable _mathSymbols
    if {[dict exists $_mathSymbols $name]} {
        return [dict get $_mathSymbols $name]
    }
    return ""
}

proc ::pdf4tcllib::text::mathSymbolNames {} {
    # A sorted list of every known symbol name.
    # Useful for documentation, tab completion and tests.
    variable _mathSymbols
    return [lsort [dict keys $_mathSymbols]]
}


# ================================================================
# Module: pdf4tcllib::math
# ================================================================
#
# pdf4tcllib::math -- inline maths rendering into the PDF
#
# Inspired by Arjen Markus' "MathFormula" on wiki.tcl-lang.org (Rendering
# mathematical formulae, 2002-2007); the notation is carried over to
# pdf4tcl output instead of a Tk canvas.
#
# Notation -- every token separated by whitespace:
#   alpha beta gamma   Greek letters, LaTeX style, lower case
#   Alpha Beta Sigma   Greek capitals
#   x ^ 2              superscript
#   H _ 2 O            subscript, then O
#   ~                  forced space
#   SUM PROD INT       large operators
#   from ... to ...    limits below/above SUM/INT/PROD
#   infty sqrt cdot    maths symbols, see text::mathSymbolNames
#
# Examples:
#   "alpha + beta = gamma"
#   "x ^ 2 + y ^ 2 = r ^ 2"
#   "SUM from i=0 to infty ~ a _ i"
#   "INT from 0 to pi cos ^ 2 x dx"
#
# Public API:
#   pdf4tcllib::math::renderFormula pdf x y formula ?-size N? ?-font NAME?
#       Renders formula at (x,y) into the PDF. Returns the end x position.
#
#   pdf4tcllib::math::analyseFormula formula
#       Tokenises formula. Returns a list of {token xp yp advance}.
#       Useful for a renderer of your own.
#
# Requires:
#   pdf4tcllib::fonts::init -cid 1   -- for Greek and maths symbols

namespace eval ::pdf4tcllib::math {
    namespace export renderFormula analyseFormula
    variable _warned
    array set _warned {}
}

# One-time warning (per unknown symbol) so an unresolved LaTeX command that
# falls through to its raw name does not pass unnoticed.
proc ::pdf4tcllib::math::_warnUnknown {name} {
    variable _warned
    if {[info exists _warned($name)]} { return }
    set _warned($name) 1
    puts stderr "pdf4tcllib::math: unknown symbol '\\$name' rendered as literal text"
}

# ----------------------------------------------------------------
# analyseFormula -- Token-Parser
# ----------------------------------------------------------------
proc ::pdf4tcllib::math::analyseFormula {formula} {
    set result  [list]
    set advance 1
    set xp      0
    set yp      0
    # Limit offsets for SUM/INT/PROD, used by from/to
    set xtop  -8 ; set ytop  -8
    set xbot  -8 ; set ybot   8
    # Letzter Operator war SUM/INT/PROD? Wenn ja, sind from/to Limits;
    # sonst werden from/to literal als Text gerendert.

    foreach token $formula {
        switch -- $token {
            "_" { # Subscript: naechstes Token tiefgestellt
                set yp 5
                set advance 0
                continue
            }
            "^" { # Superscript
                set yp -5
                set advance 0
                continue
            }
            "~" { # Forced space
                set token   " "
                set advance 1
            }
            "INT" { # Integral
                set xp 0; set yp 0
                set xtop  -3 ; set ytop  -8
                set xbot  -5 ; set ybot  10
                set advance 1
            }
            "SUM" - "PROD" { # Sum, Product
                set xp 0; set yp 0
                set xtop -12 ; set ytop  -8
                set xbot  -8 ; set ybot  12
                set advance 1
            }
            "from" { # Unterer Limit -- Arjen-Konvention: always limit
                set xp $xbot ; set yp $ybot
                set advance 0
                continue
            }
            "to" { # Oberer Limit -- Arjen-Konvention: always limit
                # For the arrow symbol itself, write "rightarrow"
                set xp $xtop ; set yp $ytop
                set advance 0
                continue
            }
            default {
                set advance 1
            }
        }
        lappend result $token $xp $yp $advance
        if {$advance} { set xp 0; set yp 0 }
    }
    return $result
}

# ----------------------------------------------------------------
# renderFormula -- PDF-Renderer
# ----------------------------------------------------------------
proc ::pdf4tcllib::math::renderFormula {pdf x y formula args} {
    # Optionen
    array set opt {-size 12 -font ""}
    array set opt $args

    set fontSize $opt(-size)
    set font     $opt(-font)
    if {$font eq ""} {
        # Default: the TTF sans face when loaded, otherwise Helvetica
        if {[::pdf4tcllib::fonts::hasTtf]} {
            set font [::pdf4tcllib::fonts::fontSans]
        } else {
            set font Helvetica
        }
    }

    set tokens [analyseFormula $formula]
    set xpos $x

    foreach {token xp yp advance} $tokens {
        # 1. symbol lookup
        #    - directly first (alpha -> greek alpha, le -> less-or-equal)
        #    - SUM/INT/PROD: look up the lower case variant
        set glyph [::pdf4tcllib::text::mathSymbol $token]
        if {$glyph eq ""} {
            # Operator-Aliase: SUM -> sum, INT -> int, PROD -> prod
            switch -- $token {
                "SUM"  { set glyph [::pdf4tcllib::text::mathSymbol sum] }
                "INT"  { set glyph [::pdf4tcllib::text::mathSymbol int] }
                "PROD" { set glyph [::pdf4tcllib::text::mathSymbol prod] }
            }
        }
        if {$glyph eq ""} {
            # Kein Symbol -- Token literal verwenden
            set glyph $token
        }

        # 2. compute the position (xp/yp relative to the cursor)
        set drawX [expr {$xpos + $xp}]
        set drawY [expr {$y + $yp}]

        # 3. Sub/Super-Erkennung: yp != 0 -> kleinere Schrift
        if {$yp != 0} {
            set smallSize [expr {$fontSize * 0.7}]
            $pdf setFont $smallSize $font
            $pdf text $glyph -x $drawX -y $drawY
            set w [$pdf getStringWidth $glyph]
            $pdf setFont $fontSize $font
        } else {
            $pdf setFont $fontSize $font
            $pdf text $glyph -x $drawX -y $drawY
            set w [$pdf getStringWidth $glyph]
        }

        # 4. advance the x cursor when advance=1
        if {$advance} {
            set xpos [expr {$drawX + $w}]
        }
    }

    return $xpos
}


# ----------------------------------------------------------------
# renderLatex -- box-model LaTeX-subset renderer
# ----------------------------------------------------------------
# Complements renderFormula (linear token list) with a recursive box
# model: grouped/nested ^{} _{}, \frac, \sqrt, \int/\sum/\prod with
# stacked limits. Pure Tcl on pdf4tcl primitives (text + line).
#
# Supported subset:
#   - plain chars, + - = ( ) ...
#   - \alpha..\omega, \infty, \pi, \le, \forall, \to ... (via mathSymbol)
#   - ^{...} _{...} grouped super/subscript (also single token x^2)
#   - \frac{num}{den}, \sqrt{...}
#   - \int \sum \prod with _{lower} ^{upper} as stacked limits
#   - \, \; \: thin spaces ; { } grouping
#
# Usage:
#   pdf4tcllib::math::renderLatex $pdf $x $y $latex ?-size 12? ?-font name?
#   -> returns total advance width; baseline at $y.
#
# Note: not a full LaTeX math mode (no \left\right sizing, matrices,
# \text). Measure helpers (_latexMeasure*) expose w/h/d so callers can
# centre or page-fit display formulas before drawing.

namespace eval ::pdf4tcllib::math {
    namespace export renderLatex measureLatex renderLatexOn measureLatexOn \
        pdfBackend canvasBackend
    # Encoding-safe fallback for names mathSymbol lacks. \uXXXX escapes
    # are independent of how this file is sourced.
    variable latexFallback
    array set latexFallback [list \
        neq         \u2260 \
        ne          \u2260 \
        leftrightarrow \u2194 \
        Leftrightarrow \u21d4 \
        Rightarrow  \u21d2 \
        Leftarrow   \u21d0 \
        rightarrow  \u2192 \
        leftarrow   \u2190 \
        mp          \u2213 \
        notin       \u2209 \
        emptyset    \u2205 \
        cdots       \u22ef \
        ldots       \u2026 ]
}

proc ::pdf4tcllib::math::_latexSymbol {name} {
    variable latexFallback
    # Primary: reuse the text symbol table (alpha, pi, infty, int, le ...)
    set g ""
    catch { set g [::pdf4tcllib::text::mathSymbol $name] }
    if {$g ne ""} { return $g }
    if {[info exists latexFallback($name)]} { return $latexFallback($name) }
    _warnUnknown $name
    return $name
}

# ---- Tokenizer ----
proc ::pdf4tcllib::math::_latexTokenize {s} {
    set toks {}
    set i 0; set n [string length $s]
    while {$i < $n} {
        set c [string index $s $i]
        if {$c eq "\\"} {
            set j [expr {$i+1}]
            if {[string match {[A-Za-z]} [string index $s $j]]} {
                set k $j
                while {$k < $n && [string match {[A-Za-z]} [string index $s $k]]} { incr k }
                lappend toks [list cmd [string range $s $j [expr {$k-1}]]]
                set i $k
            } else {
                set p [string index $s $j]
                if {$p in {, ; :}} {
                    lappend toks [list space {}]
                } else {
                    lappend toks [list char $p]
                }
                set i [expr {$j+1}]
            }
        } elseif {$c eq "\{"} { lappend toks [list open {}];  incr i
        } elseif {$c eq "\}"} { lappend toks [list close {}]; incr i
        } elseif {$c eq "^"}  { lappend toks [list sup {}];   incr i
        } elseif {$c eq "_"}  { lappend toks [list sub {}];   incr i
        } elseif {$c eq " "}  { incr i
        } else                { lappend toks [list char $c];  incr i }
    }
    return $toks
}

# ---- Parser: tokens -> list of atoms ----
proc ::pdf4tcllib::math::_latexParseGroup {toksVar} {
    upvar 1 $toksVar toks
    set atoms {}
    while {[llength $toks]} {
        set t [lindex $toks 0]
        lassign $t kind val
        if {$kind eq "close"} { set toks [lrange $toks 1 end]; break }
        set toks [lrange $toks 1 end]
        switch -- $kind {
            char  { lappend atoms [list sym $val] }
            space { lappend atoms [list space {}] }
            open  { lappend atoms [list grp [_latexParseGroup toks]] }
            sup   { _latexAttachScript atoms sup toks }
            sub   { _latexAttachScript atoms sub toks }
            cmd {
                switch -- $val {
                    frac {
                        set num [_latexParseArg toks]; set den [_latexParseArg toks]
                        lappend atoms [list frac $num $den]
                    }
                    sqrt {
                        lappend atoms [list sqrt [_latexParseArg toks]]
                    }
                    int - sum - prod {
                        lappend atoms [list bigop $val {} {}]
                    }
                    default { lappend atoms [list sym [_latexSymbol $val]] }
                }
            }
        }
    }
    return $atoms
}

# Parse one argument: either {group} or a single token
proc ::pdf4tcllib::math::_latexParseArg {toksVar} {
    upvar 1 $toksVar toks
    if {![llength $toks]} { return {} }
    set t [lindex $toks 0]; lassign $t kind val
    set toks [lrange $toks 1 end]
    switch -- $kind {
        open { return [_latexParseGroup toks] }
        char { return [list [list sym $val]] }
        cmd  {
            switch -- $val {
                frac { set num [_latexParseArg toks]; set den [_latexParseArg toks]
                       return [list [list frac $num $den]] }
                sqrt { return [list [list sqrt [_latexParseArg toks]]] }
                int - sum - prod { return [list [list bigop $val {} {}]] }
                default { return [list [list sym [_latexSymbol $val]]] }
            }
        }
        default { return {} }
    }
}

# Attach a sup/sub to the preceding atom (or to a bigop as a limit)
proc ::pdf4tcllib::math::_latexAttachScript {atomsVar which toksVar} {
    upvar 1 $atomsVar atoms
    upvar 1 $toksVar toks
    set arg [_latexParseArg toks]
    if {![llength $atoms]} { lappend atoms [list sym ""] }
    set last [lindex $atoms end]
    lassign $last lk
    if {$lk eq "bigop"} {
        lassign $last _ op lower upper
        if {$which eq "sub"} { set lower $arg } else { set upper $arg }
        lset atoms end [list bigop $op $lower $upper]
        return
    }
    if {$lk eq "scripted"} {
        lassign $last _ base sub sup
        if {$which eq "sub"} { set sub $arg } else { set sup $arg }
        lset atoms end [list scripted $base $sub $sup]
        return
    }
    if {$which eq "sub"} {
        lset atoms end [list scripted $last $arg {}]
    } else {
        lset atoms end [list scripted $last {} $arg]
    }
}

# ---- Measure (returns {width heightAboveBaseline depthBelow}) ----
proc ::pdf4tcllib::math::_latexMeasureList {be font size atoms} {
    set w 0.0; set h [expr {$size*0.7}]; set d [expr {$size*0.2}]
    foreach a $atoms {
        lassign [_latexMeasureAtom $be $font $size $a] aw ah ad
        set w [expr {$w + $aw}]
        if {$ah > $h} { set h $ah }
        if {$ad > $d} { set d $ad }
    }
    return [list $w $h $d]
}

proc ::pdf4tcllib::math::_latexMeasureAtom {be font size a} {
    set kind [lindex $a 0]
    switch -- $kind {
        sym {
            set g [lindex $a 1]
            return [list [{*}$be width $font $size $g] \
                [expr {$size*0.72}] [expr {$size*0.20}]]
        }
        space { return [list [expr {$size*0.3}] 0 0] }
        grp   { return [_latexMeasureList $be $font $size [lindex $a 1]] }
        scripted {
            lassign $a _ base sub sup
            lassign [_latexMeasureAtom $be $font $size $base] bw bh bd
            set ss [expr {$size*0.7}]
            set sw 0.0; set extraH 0; set extraD 0
            if {[llength $sup]} {
                lassign [_latexMeasureList $be $font $ss $sup] supw suph supd
                if {$supw>$sw} { set sw $supw }
                set extraH [expr {$bh*0.5}]
            }
            if {[llength $sub]} {
                lassign [_latexMeasureList $be $font $ss $sub] subw subh subd
                if {$subw>$sw} { set sw $subw }
                set extraD [expr {$bd+$ss*0.4}]
            }
            return [list [expr {$bw+$sw}] [expr {$bh+$extraH}] [expr {$bd+$extraD}]]
        }
        frac {
            lassign $a _ num den
            lassign [_latexMeasureList $be $font [expr {$size*0.85}] $num] nw nh nd
            lassign [_latexMeasureList $be $font [expr {$size*0.85}] $den] dw dh dd
            return [list [expr {max($nw,$dw)+4}] [expr {$nh+$nd+2+$size*0.3}] [expr {$dh+$dd+2}]]
        }
        sqrt {
            lassign $a _ arg
            lassign [_latexMeasureList $be $font $size $arg] aw ah ad
            return [list [expr {$aw+$size*0.7+2}] [expr {$ah+2}] $ad]
        }
        bigop {
            return [list [expr {$size*1.1}] [expr {$size*1.0}] [expr {$size*1.05}]]
        }
    }
    return [list 0 0 0]
}

# ---- Draw (baseline at $y; returns advance x) ----
proc ::pdf4tcllib::math::_latexDrawList {be font size x y atoms} {
    set cx $x
    foreach a $atoms {
        set cx [_latexDrawAtom $be $font $size $cx $y $a]
    }
    return $cx
}

proc ::pdf4tcllib::math::_latexDrawAtom {be font size x y a} {
    set kind [lindex $a 0]
    switch -- $kind {
        sym {
            set g [lindex $a 1]
            {*}$be text $font $size $x $y $g
            return [expr {$x+[{*}$be width $font $size $g]}]
        }
        space { return [expr {$x+$size*0.3}] }
        grp   { return [_latexDrawList $be $font $size $x $y [lindex $a 1]] }
        scripted {
            lassign $a _ base sub sup
            set bx [_latexDrawAtom $be $font $size $x $y $base]
            set ss [expr {$size*0.7}]
            if {[llength $sup]} { _latexDrawList $be $font $ss $bx [expr {$y-$size*0.45}] $sup }
            if {[llength $sub]} { _latexDrawList $be $font $ss $bx [expr {$y+$size*0.28}] $sub }
            lassign [_latexMeasureAtom $be $font $size $a] aw ah ad
            return [expr {$x+$aw}]
        }
        frac {
            lassign $a _ num den
            set fs [expr {$size*0.85}]
            lassign [_latexMeasureList $be $font $fs $num] nw nh nd
            lassign [_latexMeasureList $be $font $fs $den] dw dh dd
            set w [expr {max($nw,$dw)+4}]
            set midY [expr {$y-$size*0.25}]
            _latexDrawList $be $font $fs [expr {$x+($w-$nw)/2.0}] [expr {$midY-2-$nd}] $num
            _latexDrawList $be $font $fs [expr {$x+($w-$dw)/2.0}] [expr {$midY+2+$dh}] $den
            {*}$be line $x $midY [expr {$x+$w}] $midY 0.6
            return [expr {$x+$w}]
        }
        sqrt {
            lassign $a _ arg
            set radW [expr {$size*0.6}]
            lassign [_latexMeasureList $be $font $size $arg] aw ah ad
            set topY [expr {$y-$ah}]
            {*}$be line $x [expr {$y-$size*0.25}] \
                [expr {$x+$radW*0.4}] [expr {$y+$ad*0.5}] 0.7
            {*}$be line [expr {$x+$radW*0.4}] [expr {$y+$ad*0.5}] \
                [expr {$x+$radW*0.65}] $topY 0.7
            {*}$be line [expr {$x+$radW*0.65}] $topY \
                [expr {$x+$radW+$aw+2}] $topY 0.7
            set ax [_latexDrawList $be $font $size [expr {$x+$radW+1}] $y $arg]
            return [expr {$ax+1}]
        }
        bigop {
            lassign $a _ op lower upper
            set bs [expr {$size*1.6}]
            set g [_latexSymbol $op]
            set ow [{*}$be width $font $bs $g]
            lassign [_latexMeasureAtom $be $font $size $a] aw ah ad
            {*}$be text $font $bs [expr {$x+($aw-$ow)/2.0}] \
                [expr {$y+$size*0.35}] $g
            set ls [expr {$size*0.62}]
            if {[llength $upper]} {
                lassign [_latexMeasureList $be $font $ls $upper] uw uh ud
                _latexDrawList $be $font $ls [expr {$x+($aw-$uw)/2.0}] [expr {$y-$size*0.95}] $upper
            }
            if {[llength $lower]} {
                lassign [_latexMeasureList $be $font $ls $lower] lw lh ld
                # under-limit lowered (0.95 -> 1.18) so e.g. \sum_{n=1} is not
                # cramped against the operator; measure depth raised to match.
                _latexDrawList $be $font $ls [expr {$x+($aw-$lw)/2.0}] [expr {$y+$size*1.18}] $lower
            }
            return [expr {$x+$aw+1}]
        }
    }
    return $x
}

# ---- Backends ------------------------------------------------------------
#
# The engine above never touches pdf4tcl directly. It talks to a backend: a
# command prefix understanding three operations, and nothing else.
#
#   {*}$be width $font $size $text            -> width of $text
#   {*}$be text  $font $size $x $y $text      -> draw, baseline at $y
#   {*}$be line  $x1 $y1 $x2 $y2 $width       -> draw a line
#
# Both coordinate systems agree: y grows DOWNWARD (pdf4tcl and the Tk canvas
# both do), so the same geometry serves both. A backend that needs y upward
# would have to flip it itself.
#
# This is what makes the formula engine backend-neutral: measuring and drawing
# are the same code for PDF and for a Tk canvas -- only the three primitives
# differ.

# Backend for a pdf4tcl handle. This is what renderLatex/measureLatex use.
proc ::pdf4tcllib::math::pdfBackend {pdf} {
    return [list ::pdf4tcllib::math::_pdfBackend $pdf]
}

proc ::pdf4tcllib::math::_pdfBackend {pdf op args} {
    switch -- $op {
        width {
            lassign $args font size text
            # Leerer Vorgabewert heisst: nimm, was fonts:: liefert. Ein fest
    # verdrahtetes Helvetica machte jedes Dokument PDF/A-untauglich --
    # die vierzehn Standardschriften haben kein einbettbares
    # Fontprogramm, und veraPDF faellt darueber (Klausel 6.2.11.4.1).
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }
    $pdf setFont $size $font
            return [$pdf getStringWidth $text]
        }
        text {
            lassign $args font size x y text
            # Leerer Vorgabewert heisst: nimm, was fonts:: liefert. Ein fest
    # verdrahtetes Helvetica machte jedes Dokument PDF/A-untauglich --
    # die vierzehn Standardschriften haben kein einbettbares
    # Fontprogramm, und veraPDF faellt darueber (Klausel 6.2.11.4.1).
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }
    $pdf setFont $size $font
            # Ueber safeText statt direkt: eine Formel besteht ueberwiegend
            # aus Zeichen, die eine Standardschrift nicht hat. Vorher gingen
            # die als "?" durch, ohne Zaehler und ohne Wort -- gemessen
            # ergab "\alpha \sum" ohne fonts::init -cid 1 sechs
            # Fragezeichen im Inhaltsstrom.
            ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y
            return
        }
        line {
            lassign $args x1 y1 x2 y2 lw
            $pdf setLineWidth $lw
            $pdf line $x1 $y1 $x2 $y2
            return
        }
    }
    return -code error -errorcode {PDF4TCLLIB MATH BACKEND} \
        "unknown backend operation '$op'"
}

# Backend for a Tk canvas.
#
#   -family  Tk font family used for the formula (default: TkDefaultFont's).
#   -fill    colour of glyphs and rules (default: black).
#   -tags    canvas tags put on every item (default: none) -- makes the whole
#            formula deletable/movable as a unit.
#
# The engine's font argument is ignored here: a PDF font name means nothing to
# Tk. The SIZE is honoured, and that is what matters -- the engine scales it
# for scripts, fractions and big operators.
proc ::pdf4tcllib::math::canvasBackend {canvas args} {
    array set opt {-family "" -fill black -tags {}}
    array set opt $args
    set family $opt(-family)
    if {$family eq ""} {
        set family [font actual TkDefaultFont -family]
    }
    return [list ::pdf4tcllib::math::_canvasBackend \
        $canvas $family $opt(-fill) $opt(-tags)]
}

# Tk font sizes are integers. Rounding once, here, keeps measuring and drawing
# consistent -- both go through this proc.
proc ::pdf4tcllib::math::_canvasFont {family size} {
    set s [expr {int(round($size))}]
    if {$s < 1} { set s 1 }
    return [list $family $s]
}

proc ::pdf4tcllib::math::_canvasBackend {canvas family fill tags op args} {
    switch -- $op {
        width {
            lassign $args font size text
            return [font measure [_canvasFont $family $size] $text]
        }
        text {
            lassign $args font size x y text
            set f [_canvasFont $family $size]
            # The Tk canvas has no baseline anchor. "sw" is the bottom left of
            # the text box, which sits one descent below the baseline -- so
            # shift by exactly that and the formula lines up with the engine's
            # baseline maths.
            set dy [font metrics $f -descent]
            $canvas create text $x [expr {$y + $dy}] -text $text \
                -anchor sw -font $f -fill $fill -tags $tags
            return
        }
        line {
            lassign $args x1 y1 x2 y2 lw
            $canvas create line $x1 $y1 $x2 $y2 -width $lw -fill $fill \
                -tags $tags
            return
        }
    }
    return -code error -errorcode {PDF4TCLLIB MATH BACKEND} \
        "unknown backend operation '$op'"
}

# ---- Public API ----------------------------------------------------------

# {width heightAboveBaseline depthBelow} of a formula on any backend.
proc ::pdf4tcllib::math::measureLatexOn {be latex args} {
    array set opt {-size 12 -font ""}
    array set opt $args
    set toks  [_latexTokenize $latex]
    set atoms [_latexParseGroup toks]
    return [_latexMeasureList $be $opt(-font) $opt(-size) $atoms]
}

# Draw a formula on any backend, baseline at $y. Returns the advanced x.
proc ::pdf4tcllib::math::renderLatexOn {be x y latex args} {
    array set opt {-size 12 -font ""}
    array set opt $args
    set toks  [_latexTokenize $latex]
    set atoms [_latexParseGroup toks]
    return [_latexDrawList $be $opt(-font) $opt(-size) $x $y $atoms]
}

# Default PDF font when the caller does not name one.
proc ::pdf4tcllib::math::_defaultPdfFont {} {
    if {[::pdf4tcllib::fonts::hasTtf]} {
        return [::pdf4tcllib::fonts::fontSans]
    }
    return Helvetica
}

proc ::pdf4tcllib::math::measureLatex {pdf latex args} {
    # Returns {width heightAboveBaseline depthBelow} for a LaTeX-subset
    # string, so callers can centre or page-fit before renderLatex.
    array set opt {-size 12 -font ""}
    array set opt $args
    if {$opt(-font) eq ""} { set opt(-font) [_defaultPdfFont] }
    return [measureLatexOn [pdfBackend $pdf] $latex \
        -size $opt(-size) -font $opt(-font)]
}

proc ::pdf4tcllib::math::renderLatex {pdf x y latex args} {
    array set opt {-size 12 -font ""}
    array set opt $args
    if {$opt(-font) eq ""} { set opt(-font) [_defaultPdfFont] }
    return [renderLatexOn [pdfBackend $pdf] $x $y $latex \
        -size $opt(-size) -font $opt(-font)]
}



# ================================================================
# Module: pdf4tcllib::page
# ================================================================

# pdf4tcllib::page -- pagenkontext and pagenmoeblierung for pdf4tcl
#
# Zentrales Konzept: PageContext-Dictionary
# Wird einmal pro Dokument erzeugt and enthaelt alle berechneten
# pagenabmessungen (Margins, druckbarer Bereich etc.)
#
# Usage:
#   package require pdf4tcllib::page 0.1
#   set ctx [pdf4tcllib::page::context a4 -margin 20]
#   dict get $ctx page_w     ;# page width in points
#   dict get $ctx left        ;# Linker Rand in Points
#   dict get $ctx text_w      ;# Druckbare width
#
#   pdf4tcllib::page::number $pdf $ctx 1 10
#   pdf4tcllib::page::header $pdf $ctx "Mein Dokument"
#   pdf4tcllib::page::footer $pdf $ctx "Vertraulich" 3


namespace eval ::pdf4tcllib::page {
    # Paper sizes in points {width height}
    variable paperSizes
    array set paperSizes {
        a4      {595.28  841.89}
        a3      {841.89  1190.55}
        a5      {419.53  595.28}
        letter  {612     792}
        legal   {612     1008}
        b5      {498.90  708.66}
    }
}

# The font these blocks draw with. Helvetica unless fonts::init loaded a
# TrueType -- a caller who went to the trouble of loading one does not want
# a page number set in a font that cannot be embedded, and under PDF/UA
# that single call is enough to make the document non-conformant.
proc ::pdf4tcllib::_defaultFamily {} {
    if {[catch {::pdf4tcllib::fonts::hasTtf} ok] || !$ok} { return Helvetica }
    return [::pdf4tcllib::fonts::fontSans]
}

proc ::pdf4tcllib::page::context {paper args} {
    # Generates ein PageContext-Dictionary.
    #
    # Args:
    #   paper  - Papiergroesse: a4, a3, a5, letter, legal, b5
    #
    # Optionen (Keyword or Positional):
    #   context a4 -margin 20 -orient true   ;# Keyword
    #   context a4 20 true                   ;# Positional (Kompatibilitaet)
    #   context a4                           ;# Defaults

    variable paperSizes

    array set opt {
        -margin    20
        -landscape 0
        -orient    true
    }

    # Positional args erkennen (erstes arg beginnt not with -)
    if {[llength $args] > 0 && ![string match "-*" [lindex $args 0]]} {
        if {[llength $args] >= 1} { set opt(-margin) [lindex $args 0] }
        if {[llength $args] >= 2} { set opt(-orient) [lindex $args 1] }
    } else {
        array set opt $args
    }

    set paperKey [string tolower $paper]
    if {![info exists paperSizes($paperKey)]} {
        error "unknown paper size: $paper (known: [array names paperSizes])"
    }

    lassign $paperSizes($paperKey) pw ph

    if {$opt(-landscape)} {
        set tmp $pw
        set pw $ph
        set ph $tmp
    }

    set margin_pt [::pdf4tcllib::units::mm $opt(-margin)]

    # orient true  = top left, y grows downwards (like a Tk canvas or HTML)
    #   top    = margin_pt              small value, near y=0 at the top
    #   bottom = page_h - margin_pt     large value, near the page foot
    # orient false = bottom left, y grows upwards (the PDF default)
    #   top    = page_h - margin_pt     large value, near the page head
    #   bottom = margin_pt              small value, near y=0 at the bottom
    if {$opt(-orient)} {
        set top_y    $margin_pt
        set bottom_y [expr {$ph - $margin_pt}]
    } else {
        set top_y    [expr {$ph - $margin_pt}]
        set bottom_y $margin_pt
    }

    set ctx [dict create \
        paper      $paperKey \
        page_w     $pw \
        page_h     $ph \
        PW         $pw \
        PH         $ph \
        margin     $margin_pt \
        margin_mm  $opt(-margin) \
        margin_pt  $margin_pt \
        left       $margin_pt \
        right      [expr {$pw - $margin_pt}] \
        top        $top_y \
        bottom     $bottom_y \
        text_w     [expr {$pw - 2 * $margin_pt}] \
        text_h     [expr {$ph - 2 * $margin_pt}] \
        SX         $margin_pt \
        SY         $top_y \
        SW         [expr {$pw - 2 * $margin_pt}] \
        SH         [expr {$ph - 2 * $margin_pt}] \
        landscape  $opt(-landscape) \
        orient     $opt(-orient) \
    ]

    return $ctx
}

proc ::pdf4tcllib::page::lineheight {fontSize {factor 1.4}} {
    # Calculates the line height for a font size.
    return [expr {int(ceil($fontSize * $factor))}]
}

proc ::pdf4tcllib::page::_advance {ctx yVar step} {
    # Moves y by step in the correct direction for the current orient.
    # orient true  (y grows down): y += step
    # orient false (y grows up):   y -= step
    upvar 1 $yVar y
    if {[dict get $ctx orient]} {
        set y [expr {$y + $step}]
    } else {
        set y [expr {$y - $step}]
    }
}

proc ::pdf4tcllib::page::number {pdf ctx current {total ""} {size 9}} {
    # Writes the page number centered at bottom.
    # Supports orient true (y down) and orient false (y up).

    set orient [dict get $ctx orient]
    set x      [expr {[dict get $ctx page_w] / 2.0}]
    set m      [dict get $ctx margin]
    set ph     [dict get $ctx page_h]
    # orient true: large y = near bottom; orient false: small y = near bottom
    set y [expr {$orient ? ($ph - $m * 0.5) : ($m * 0.5)}]

    if {$total ne ""} {
        set text "- $current / $total -"
    } else {
        set text "- $current -"
    }

    # A page number is not part of what the document says; ISO 32000-1
    # clause 14.8.2.2 lists pagination among the artifact types. Tagged as
    # content a reader announces it in the middle of the running text.
    ::pdf4tcllib::tag::artifact $pdf -type Pagination
    $pdf setFont $size [::pdf4tcllib::_defaultFamily]
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y -align center
    ::pdf4tcllib::tag::artifactEnd $pdf
}

proc ::pdf4tcllib::page::header {pdf ctx text {size 10}} {
    # Writes a header centered at top.
    # Supports both orient true (y down) and orient false (y up).

    set orient [dict get $ctx orient]
    set x  [expr {[dict get $ctx page_w] / 2.0}]
    set m  [dict get $ctx margin]
    set top [dict get $ctx top]

    if {$orient} {
        # orient true: y=0 is top, header near top = small y
        set y  [expr {$m * 0.5}]
        set ly [expr {$top + 2}]
    } else {
        # orient false: y=0 is bottom, header near top = large y
        set y  [expr {$top + $m * 0.5}]
        set ly [expr {$top - 2}]
    }

    # Running head and its rule: pagination, not content (ISO 32000-1
    # clause 14.8.2.2). A reader that announces them reads the title again
    # on every page.
    ::pdf4tcllib::tag::artifact $pdf -type Pagination
    $pdf setFont $size [::pdf4tcllib::_defaultFamily]
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y -align center

    set lx [dict get $ctx left]
    set rx [dict get $ctx right]
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf line $lx $ly $rx $ly
    $pdf setStrokeColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
}

# The page label written on the right of the footer. A format string, the
# page number is substituted for %s.
#
# This is DOCUMENT CONTENT, not a message: it ends up in the PDF and a
# reader sees it. It has been the German "Seite N" since the beginning and
# stays that way by default, because silently switching the language of
# existing documents is worse than an inconsistency -- page::number next to
# it writes the language-free "- 3 / 10 -". Set it once per application, or
# per call with -pagelabel:
#
#   set ::pdf4tcllib::page::pageLabelFormat "Page %s"
#   ::pdf4tcllib::page::footer $pdf $ctx "Confidential" 3 9 -pagelabel "Page %s"
namespace eval ::pdf4tcllib::page {
    variable pageLabelFormat "Seite %s"
}

proc ::pdf4tcllib::page::footer {pdf ctx text pageNo {size 9} args} {
    # Writes a footer: text left, page number right.
    # Supports both orient true (y down) and orient false (y up).
    variable pageLabelFormat
    set label $pageLabelFormat
    foreach {k v} $args {
        switch -- $k {
            -pagelabel { set label $v }
            default {
                error "pdf4tcllib::page::footer: unknown option $k\
                        (known: -pagelabel)"
            }
        }
    }

    set orient [dict get $ctx orient]
    set ph     [dict get $ctx page_h]
    set m      [dict get $ctx margin]
    set bottom [dict get $ctx bottom]
    set lx     [dict get $ctx left]
    set rx     [dict get $ctx right]

    if {$orient} {
        # orient true: footer near bottom = large y
        set y  [expr {$ph - $m * 0.5}]
        set ly [expr {$bottom - 2}]
    } else {
        # orient false: footer near bottom = small y
        set y  [expr {$m * 0.5}]
        set ly [expr {$bottom + 2}]
    }

    # Footer and page number: pagination artifacts, like the header above.
    ::pdf4tcllib::tag::artifact $pdf -type Pagination
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf line $lx $ly $rx $ly
    $pdf setStrokeColor 0 0 0

    $pdf setFont $size [::pdf4tcllib::_defaultFamily]
    ::pdf4tcllib::unicode::safeText $pdf $text -x $lx -y $y
    ::pdf4tcllib::unicode::safeText $pdf [format $label $pageNo] \
            -x $rx -y $y -align right
    ::pdf4tcllib::tag::artifactEnd $pdf
}

proc ::pdf4tcllib::page::centerText {pdf ctx text y {size 12} {font "Helvetica"}} {
    # Writes Text horizontal zentriert.


    set x [expr {[dict get $ctx page_w] / 2.0}]
    # Leerer Vorgabewert heisst: nimm, was fonts:: liefert. Ein fest
    # verdrahtetes Helvetica machte jedes Dokument PDF/A-untauglich --
    # die vierzehn Standardschriften haben kein einbettbares
    # Fontprogramm, und veraPDF faellt darueber (Klausel 6.2.11.4.1).
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }
    $pdf setFont $size $font
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y -align center
}

proc ::pdf4tcllib::page::grid {pdf args} {
    # Draws a helper grid on the page (for debugging).
    #
    # Aufruf:
    #   page::grid $pdf $ctx          ;# spacing=50
    #   page::grid $pdf $ctx 25       ;# spacing=25
    #   page::grid $pdf 50            ;# ohne ctx, spacing=50 (Kompatibilitaet)

    set spacing 50
    set pw 595.28
    set ph 841.89

    if {[llength $args] == 0} {
        # page::grid $pdf
    } elseif {[llength $args] == 1} {
        set arg [lindex $args 0]
        if {[string is double -strict $arg]} {
            set spacing [expr {int($arg)}]
        } else {
            set pw [dict get $arg page_w]
            set ph [dict get $arg page_h]
        }
    } elseif {[llength $args] == 2} {
        set ctx [lindex $args 0]
        set spacing [lindex $args 1]
        set pw [dict get $ctx page_w]
        set ph [dict get $ctx page_h]
    }

    # A helper grid is scaffolding, never content.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    $pdf setStrokeColor 0.85 0.85 0.85
    $pdf setLineWidth 0.25

    # Vertikale Linien
    for {set x 0} {$x <= $pw} {set x [expr {$x + $spacing}]} {
        $pdf line $x 0 $x $ph
        $pdf setFont 6 [::pdf4tcllib::fonts::fontSans]
        $pdf setFillColor 0.6 0.6 0.6
        $pdf text "[expr {int($x)}]" -x [expr {$x + 2}] -y 8
    }

    # Horizontale Linien
    for {set y 0} {$y <= $ph} {set y [expr {$y + $spacing}]} {
        $pdf line 0 $y $pw $y
        $pdf setFont 6 [::pdf4tcllib::fonts::fontSans]
        $pdf setFillColor 0.6 0.6 0.6
        $pdf text "[expr {int($y)}]" -x 2 -y [expr {$y + 8}]
    }

    $pdf setStrokeColor 0 0 0
    $pdf setFillColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
}

proc ::pdf4tcllib::page::debugGrid {pdf ctx {spacing 50}} {
    # Draws a debug grid over the page.
    # Only active when the environment variable PDF4TCL_DEBUG is set.
    #
    # spacing: grid pitch in points (default 50 pt, about 17.6 mm)
    #
    # Usage:
    #   pdf4tcllib::page::debugGrid $pdf $ctx
    #   pdf4tcllib::page::debugGrid $pdf $ctx 25   ;# finer grid
    if {![info exists ::env(PDF4TCL_DEBUG)] || $::env(PDF4TCL_DEBUG) eq "0"} {
        return
    }

    set pw [dict get $ctx page_w]
    set ph [dict get $ctx page_h]

    $pdf gsave
    $pdf setStrokeColor 0.85 0.85 0.95
    $pdf setLineWidth 0.3

    # Vertikale Linien
    for {set x 0} {$x <= $pw} {set x [expr {$x + $spacing}]} {
        $pdf line $x 0 $x $ph
    }
    # Horizontale Linien
    for {set y 0} {$y <= $ph} {set y [expr {$y + $spacing}]} {
        $pdf line 0 $y $pw $y
    }

    # Beschriftung an Achsen (alle 100pt)
    $pdf setFont 6 [::pdf4tcllib::fonts::fontSans]
    $pdf setFillColor 0.6 0.6 0.8
    for {set x 0} {$x <= $pw} {set x [expr {$x + 100}]} {
        $pdf text [expr {int($x)}] -x [expr {$x + 1}] -y 8
    }
    for {set y 0} {$y <= $ph} {set y [expr {$y + 100}]} {
        $pdf text [expr {int($y)}] -x 1 -y [expr {$y + 7}]
    }

    $pdf setStrokeColor 0 0 0
    $pdf setFillColor 0 0 0
    $pdf grestore
}

proc ::pdf4tcllib::page::orientationLegend {pdf ctx} {
    # Zeigt Orientierungs-Info (Papier, orient, y-Ursprung) am oberen Rand.

    set pw [dict get $ctx page_w]
    set ph [dict get $ctx page_h]
    set orient [dict get $ctx orient]
    set paper [dict get $ctx paper]

    $pdf gsave
    $pdf setFont 8 [::pdf4tcllib::fonts::fontMono]
    $pdf setFillColor 0.5 0.5 0.5

    set text "$paper | orient=$orient | y-origin=[expr {$orient ? {top} : {bottom}}] | unit=pt"

    $pdf text $text \
        -align right \
        -x [expr {$pw - 10}] \
        -y [expr {$ph - 10}]

    $pdf grestore
}


# ================================================================
# Module: pdf4tcllib::table
# ================================================================

# pdf4tcllib::table -- Table rendering for pdf4tcl
#
# Renders tablen with Header, columnnausrichtung, Zebra-Streifen
# and automaticallyem Page break.
#
# Usage:
#   package require pdf4tcllib::table 0.1
#   pdf4tcllib::table::render $pdf $tableData \
#       -x 50 -y yVar -maxwidth 500 \
#       -fontsize 11 -pagebreak [list $yTop $yBot pageNoVar $pageW $pageH $margin]


# ---------------------------------------------------------------------------
# Tagged PDF helpers
#
# pdf4tcl 0.9.4.36 and later can carry a logical structure, which is what
# assistive technology reads instead of the order in which glyphs happen to be
# painted. A table is where that matters most: without it a screen reader
# announces a grid of unrelated numbers, and PDF/UA cannot be reached at all.
#
# Tagging is not switched on here. The caller decides, with
#
#     $pdf tagged 1 -lang de-DE
#
# and everything below then marks up what it draws. When tagging is off, or
# when the pdf4tcl in use predates it, every helper does nothing -- so
# existing code keeps working unchanged and nothing needs a new option.
#
# Detection is by asking rather than by version number: tagBegin raises
# "tagging is not enabled" when it is off, which is exactly the question we
# have. The answer is cached per object, since it cannot change mid-document.
namespace eval ::pdf4tcllib::tag {
    variable active
    array set active {}
    variable _tiefe
    array set _tiefe {}
}

proc ::pdf4tcllib::tag::isActive {pdf} {
    variable active
    if {[info exists active($pdf)]} {
        return $active($pdf)
    }
    # tagArtifact is the probe, not tagBegin: it raises the same "tagging is
    # not enabled" when off, but creates no structure element when on. A
    # tagBegin/tagEnd pair looks harmless and is not -- measured, it left an
    # empty Span sitting in the tree next to the table.
    if {[catch {$pdf tagArtifact}]} {
        set active($pdf) 0
    } else {
        catch {$pdf tagArtifactEnd}
        set active($pdf) 1
    }
    return $active($pdf)
}

proc ::pdf4tcllib::tag::forget {pdf} {
    variable _tiefe
    unset -nocomplain _tiefe($pdf)
    variable active
    unset -nocomplain active($pdf)
}

# Open a structure element, or do nothing when tagging is off.
# Wie tief steckt dieses Dokument gerade in offenen Elementen?
#
# Gebraucht wird das von Bausteinen, die selbst zeichnen und nicht wissen
# koennen, ob ihr Aufrufer sie schon ausgezeichnet hat -- safeText etwa.
# Ohne diese Auskunft muessten sie entweder ein Loch lassen oder ein
# Element in ein gleichartiges schachteln.
proc ::pdf4tcllib::tag::depth {pdf} {
    variable _tiefe
    if {![info exists _tiefe($pdf)]} { return 0 }
    return $_tiefe($pdf)
}

proc ::pdf4tcllib::tag::begin {pdf type args} {
    if {![isActive $pdf]} { return }
    variable _tiefe
    if {![catch {$pdf tagBegin $type {*}$args}]} {
        if {![info exists _tiefe($pdf)]} { set _tiefe($pdf) 0 }
        incr _tiefe($pdf)
    }
}

proc ::pdf4tcllib::tag::end {pdf} {
    if {![isActive $pdf]} { return }
    variable _tiefe
    if {![catch {$pdf tagEnd}]} {
        if {[info exists _tiefe($pdf)] && $_tiefe($pdf) > 0} {
            incr _tiefe($pdf) -1
        }
    }
}

# Mark decoration -- rules, shading, grid lines. Without this a reader
# announces them as if they carried meaning.
proc ::pdf4tcllib::tag::artifact {pdf args} {
    if {![isActive $pdf]} { return }
    catch {$pdf tagArtifact {*}$args}
}

proc ::pdf4tcllib::tag::artifactEnd {pdf} {
    if {![isActive $pdf]} { return }
    catch {$pdf tagArtifactEnd}
}

# ============================================================
# state -- Zeichenzustand sichern und zuruecksetzen
# ============================================================
#
# Ein Baustein hinterlaesst Schrift und Farbe so, wie er sie zuletzt
# brauchte, nicht so, wie er sie vorfand. Gemessen an table::draw:
#
#     vorher   /Pdf4tclSansBold 20 Tf,  1 0 0 rg
#     nachher  /Pdf4tclSans 9 Tf,       0 0 0 rg
#
# Wer von Hand zeichnet, merkt es kaum; wer Bausteine hintereinander
# setzt, bekommt Ergebnisse, die von der Reihenfolge abhaengen.
#
# WARUM NICHT EINFACH gsave/grestore
#
# Das PDF-Paar q/Q sichert den Zeichenzustand samt Schrift und Farbe, und
# fuer einen Block innerhalb EINER Seite ist es das richtige Mittel. Nur
# gilt es je Inhaltsstrom, und jede Seite hat ihren eigenen: ein q auf
# Seite 1 und das Q auf Seite 2 ergibt zwei unausgeglichene Stroeme.
# Nachgemessen -- pdf4tcl meldet dabei nichts, und qpdf auch nicht, weil
# beide Stroeme fuer sich genommen lesbar bleiben.
#
# Genau das passiert bei jedem Baustein, der selbst umbrechen kann:
# table::draw, flow::columns, toc::document. Deshalb sichert dieses
# Modul den Zustand auf der Tcl-Seite und setzt ihn mit setFont und
# setFillColor zurueck -- das ueberlebt einen Seitenwechsel.
#
# Die Werte kommen nicht aus pdf4tcl: getFontMetric gibt es, einen
# Getter fuer die aktuelle Schrift oder Farbe nicht. Gesichert wird
# deshalb, was der Aufrufer selbst gesetzt hat -- er weiss es, und ein
# Layouter fuehrt es ohnehin mit.
#
#   ::pdf4tcllib::state::with $pdf {12 Helvetica} {0 0 0} {
#       ::pdf4tcllib::table::draw $pdf ...
#   }
#
# oder von Hand:
#
#   set z [::pdf4tcllib::state::save $pdf 12 Helvetica {0 0 0}]
#   ...
#   ::pdf4tcllib::state::restore $pdf $z
namespace eval ::pdf4tcllib::state {}

# Einen Zustand festhalten. Schrift und Farbe gibt der Aufrufer an,
# weil pdf4tcl sie nicht herausgibt.
proc ::pdf4tcllib::state::save {pdf {size {}} {font {}} {fill {}} {stroke {}}} {
    set z [dict create]
    if {$size ne "" && $font ne ""} {
        dict set z size $size
        dict set z font $font
    }
    if {[llength $fill]   == 3} { dict set z fill   $fill }
    if {[llength $stroke] == 3} { dict set z stroke $stroke }
    # Was pdf4tcl doch herausgibt, wird nicht abgefragt, sondern
    # mitgenommen: Zeilenabstand und Kerning aendern, was ein Text misst.
    catch {dict set z linespacing [$pdf getLineSpacing]}
    catch {dict set z kerning     [$pdf getKerning]}
    return $z
}

# Den Zustand wieder herstellen. Was nicht gesichert wurde, wird nicht
# angefasst -- eine Voreinstellung waere hier eine Behauptung.
proc ::pdf4tcllib::state::restore {pdf z} {
    if {[dict exists $z size] && [dict exists $z font]} {
        catch {$pdf setFont [dict get $z size] [dict get $z font]}
    }
    if {[dict exists $z fill]} {
        catch {$pdf setFillColor {*}[dict get $z fill]}
    }
    if {[dict exists $z stroke]} {
        catch {$pdf setStrokeColor {*}[dict get $z stroke]}
    }
    if {[dict exists $z linespacing]} {
        catch {$pdf setLineSpacing [dict get $z linespacing]}
    }
    if {[dict exists $z kerning]} {
        catch {$pdf setKerning [dict get $z kerning]}
    }
    return
}

# Ein Block, um den herum der Zustand erhalten bleibt -- auch wenn der
# Block wirft. Das Ergebnis des Blocks kommt zurueck.
proc ::pdf4tcllib::state::with {pdf schrift farbe script} {
    set size {} ; set font {}
    if {[llength $schrift] == 2} { lassign $schrift size font }
    set z [save $pdf $size $font $farbe]
    set rc [catch {uplevel 1 $script} res opts]
    restore $pdf $z
    if {$rc} { return -options $opts $res }
    return $res
}

# ============================================================
# measure -- messen, ohne zu zeichnen
# ============================================================
#
# Ein Layouter muss fragen koennen: WIE HOCH wird dieser Block bei 300
# Punkt Breite -- und zwar bevor er weiss, auf welche Seite er kommt.
# Kein Baustein dieser Bibliothek beantwortet das; alle zeichnen und
# geben hinterher ein y zurueck.
#
# Der billige Weg waere, jeder Zeichenprozedur ein -dryrun beizubringen.
# Das hiesse, in jeder von ihnen zwei Faelle zu fuehren, und der
# Messfall wuerde seltener benutzt als der Zeichenfall -- also wuerde er
# als erster falsch. Stattdessen wird hier WIRKLICH gezeichnet, nur in
# ein Wegwerf-Dokument, das nie geschrieben wird. Was gemessen wird, ist
# damit per Bauart dasselbe, was spaeter herauskommt.
#
# Geladene Schriften sind objektuebergreifend (::pdf4tcl fuehrt sie im
# Namensraum, nicht je Dokument), das Wegwerf-Dokument kennt also
# dieselben Fonts. Nachgemessen mit einer CID-Schrift: gleiche Breite in
# beiden Objekten.
#
#   set m [::pdf4tcllib::measure::block mpdf {
#       ::pdf4tcllib::table::draw $mpdf 0 0 $cols $rows -maxwidth 400
#   } -paper a4]
#   dict get $m height     ;# wieviel Hoehe der Block braucht
#   dict get $m pages      ;# ueber wieviele Seiten er laeuft
#   dict get $m value      ;# was der Block zurueckgab
#
# Die Hoehe kommt aus dem Rueckgabewert des Blocks, wenn der eine Zahl
# ist -- die Bausteine geben ihr y zurueck. Ist er es nicht, steht dort
# der leere String: geraten wird nicht.
namespace eval ::pdf4tcllib::measure {}

proc ::pdf4tcllib::measure::block {varName script args} {
    array set o {-paper a4 -orient 1 -margin 0 -y 0 -landscape 0}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "measure::block: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    set mpdf [::pdf4tcl::new %AUTO% -paper $o(-paper) -orient $o(-orient) \
            -margin $o(-margin) -landscape $o(-landscape)]
    # Die Blatthoehe des Wegwerf-Dokuments, um Ueberlauf erkennen zu
    # koennen. getPageSize liefert {breite hoehe} in Punkt.
    set blatthoehe ""
    catch {set blatthoehe [lindex [$mpdf getPageSize] 1]}
    # upvar auf einen Namen, den der Aufrufer schon benutzt, waere ein
    # Fehler ("variable already exists"); deshalb erst freimachen.
    upvar 1 $varName zielVar
    catch {unset zielVar}
    upvar 1 $varName zielVar
    set zielVar $mpdf
    $mpdf startPage
    set rc [catch {uplevel 1 $script} res opts]
    catch {$mpdf endPage}
    set seiten 1
    catch {set seiten [$mpdf pageCount]}
    catch {$mpdf destroy}
    if {$rc} { return -options $opts $res }

    set hoehe ""
    if {[string is double -strict $res]} {
        set hoehe [expr {abs($res - $o(-y))}]
    }

    # UEBERLAUF -- was pages nicht sieht.
    #
    # Die Seitenzahl steigt nur, wenn der Baustein SELBST umbricht. Ein
    # Baustein, der das nicht tut (text::writeParagraph zum Beispiel),
    # laeuft stattdessen unten aus dem Blatt heraus, und pages bleibt 1.
    # Gemessen am 2026-08-29: ein Absatz mit 30 Wiederholungen auf a4
    # ergab height 1207 bei einer Blatthoehe von 841,89 -- 71 Textzeilen,
    # die letzte bei y=-7,3, also unter dem Blatt. measure und der echte
    # Lauf waren sich einig, und beide lagen daneben.
    #
    # Und keins der beiden Pruefwerkzeuge sieht es: geometry-check schaut
    # nicht auf Text, layout-check liest ueber pdftotext, und pdftotext
    # laesst weg, was neben dem Blatt liegt (359 von 360 Woertern).
    #
    # Deshalb hier, wo die Blatthoehe bekannt ist: overflow ist 1, wenn
    # der Endpunkt ueber die Blattkante hinausgeht, sonst 0 -- und "",
    # wenn sich das nicht entscheiden laesst.
    set ueberlauf ""
    if {$blatthoehe ne "" && [string is double -strict $res]} {
        if {$o(-orient)} {
            set ueberlauf [expr {$res > $blatthoehe ? 1 : 0}]
        } else {
            set ueberlauf [expr {$res < 0 ? 1 : 0}]
        }
    }
    return [dict create height $hoehe pages $seiten value $res \
            overflow $ueberlauf sheet $blatthoehe]
}

# Nur die Hoehe. Leerer String, wenn der Block sie nicht hergibt.
proc ::pdf4tcllib::measure::height {varName script args} {
    set m [uplevel 1 [list ::pdf4tcllib::measure::block $varName $script \
            {*}$args]]
    return [dict get $m height]
}

# Passt der Block in $platz Punkt Hoehe, ohne umzubrechen?
#
# Geprueft wird beides: die Hoehe UND die Seitenzahl. Ein Block kann in
# die Hoehe passen und trotzdem umgebrochen haben, wenn das
# Wegwerf-Dokument kleiner war als der Platz -- deshalb sollte -paper
# dem echten Dokument entsprechen.
proc ::pdf4tcllib::measure::fits {platz varName script args} {
    set m [uplevel 1 [list ::pdf4tcllib::measure::block $varName $script \
            {*}$args]]
    set h [dict get $m height]
    if {$h eq ""} { return "" }
    # Drei Bedingungen, und die dritte fehlte bis 0.6.4: der Block darf
    # nicht ueber die Blattkante gelaufen sein. Ohne sie sagte fits ja
    # fuer einen Absatz, der auf keine Seite passt -- die Hoehe war
    # kleiner als der genannte Platz, die Seitenzahl 1, und der Text lag
    # trotzdem zum Teil neben dem Blatt. Siehe overflow in block.
    if {[dict get $m overflow] eq "1"} { return 0 }
    return [expr {$h <= $platz && [dict get $m pages] == 1}]
}

# ============================================================
# layout::stack -- Bloecke untereinander setzen
# ============================================================
#
# Was ein Aufrufer heute von Hand schreibt: einen Block zeichnen, das
# zurueckgegebene y nehmen, einen Abstand addieren, den naechsten
# zeichnen -- und beim Seitenumbruch selbst aufpassen. Das ist die
# Schleife, die jeder Bericht enthaelt, und sie ist jedes Mal ein wenig
# anders falsch.
#
# stack macht daraus einen Aufruf und benutzt dabei, was heute dazukam:
# measure, um VORHER zu wissen, ob ein Block noch auf die Seite passt,
# und state, damit ein Block dem naechsten nicht die Schrift verstellt.
#
#   ::pdf4tcllib::layout::stack $pdf $x $y $w {
#       {script {::pdf4tcllib::text::writeParagraph $bpdf "..." $bx $by $bw}}
#       {gap 12}
#       {script {::pdf4tcllib::table::draw $bpdf $bx $by $cols $rows \
#                        -maxwidth $bw} keep 1}
#   } -ctx $ctx -font {10 Helvetica} -fill {0 0 0}
#
# In jedem script stehen bereit:
#
#   $bpdf   das Dokument -- NICHT $pdf. Beim Messen ist es ein
#           Wegwerf-Dokument, beim Zeichnen das echte; wer $pdf schreibt,
#           zeichnet beim Messen versehentlich ins richtige Dokument.
#   $bx $by $bw   Ort und Breite des Blocks
#
# Eintraege:
#   {script ...}        ein Block
#   {gap 12}            Abstand vor dem naechsten Block
#   {script ... keep 1} zusammenhalten: passt er nicht mehr ganz auf die
#                       Seite, kommt er ganz auf die naechste, statt
#                       aufgeteilt zu werden
#
# Optionen:
#   -ctx       Seitenkontext; ohne ihn wird nicht umgebrochen
#   -gap       Abstand zwischen Bloecken (0)
#   -font      {groesse name} -- wird vor jedem Block gesetzt und danach
#              wiederhergestellt
#   -fill      Fuellfarbe, ebenso
#   -pagecmd   wird nach jedem Seitenwechsel gerufen (Kopfzeile o.ae.)
#   -paper     fuers Messen (a4)
#
# Rueckgabe: dict mit
#   y        das y nach dem letzten Block
#   boxes    je Block {x y w h} -- EINE Form fuer alle, auch fuer die,
#            die von sich aus nur ein y zurueckgeben
#   pages    wieviele Seitenwechsel stattgefunden haben
namespace eval ::pdf4tcllib::layout {}

proc ::pdf4tcllib::layout::stack {pdf x y w blocks args} {
    array set o {
        -ctx {} -gap 0 -font {} -fill {} -pagecmd {} -paper a4
    }
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "layout::stack: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    set haveCtx [expr {[llength $o(-ctx)] > 0}]
    set yTop 0 ; set yBot 0
    if {$haveCtx} {
        set yTop [dict get $o(-ctx) SY]
        set yBot [expr {[dict get $o(-ctx) SY] + [dict get $o(-ctx) SH]}]
    }

    set boxes {}
    set wechsel 0
    set gap $o(-gap)

    foreach eintrag $blocks {
        if {[llength $eintrag] == 2 && [lindex $eintrag 0] eq "gap"} {
            set y [expr {$y + [lindex $eintrag 1]}]
            continue
        }
        if {![dict exists $eintrag script]} {
            return -code error "layout::stack: an entry needs a script\
                    (or must be {gap <n>})"
        }
        set script [dict get $eintrag script]
        set keep 0
        if {[dict exists $eintrag keep]} { set keep [dict get $eintrag keep] }

        # Vorher messen -- nur dafuer ist measure da. Der Block wird in
        # ein Wegwerf-Dokument gezeichnet, also muss er $bpdf benutzen.
        set hoehe ""
        if {$haveCtx && $keep} {
            set hoehe [_messen 2 $script $x $y $w $o(-paper) $o(-font) $o(-fill)]
        }
        if {$haveCtx && $hoehe ne "" && ($y + $hoehe) > $yBot && $y > $yTop} {
            $pdf endPage
            $pdf startPage
            incr wechsel
            set y $yTop
            if {$o(-pagecmd) ne ""} { uplevel 1 $o(-pagecmd) }
        }

        set vorher $y
        set z [::pdf4tcllib::state::save $pdf \
                [lindex $o(-font) 0] [lindex $o(-font) 1] $o(-fill)]
        if {[llength $o(-font)] == 2} {
            catch {$pdf setFont [lindex $o(-font) 0] [lindex $o(-font) 1]}
        }
        if {[llength $o(-fill)] == 3} {
            catch {$pdf setFillColor {*}$o(-fill)}
        }
        set res [_ausfuehren 2 $script $pdf $x $y $w]
        ::pdf4tcllib::state::restore $pdf $z

        # Eine Form fuer alle: {x y w h}. Wer ein y zurueckgibt, bekommt
        # die Hoehe daraus; wer schon eine Flaeche liefert, behaelt sie.
        if {[llength $res] == 4 && [string is double -strict [lindex $res 3]]} {
            lappend boxes $res
            set y [expr {[lindex $res 1] + [lindex $res 3]}]
        } elseif {[string is double -strict $res]} {
            lappend boxes [list $x $vorher $w [expr {$res - $vorher}]]
            set y $res
        } else {
            lappend boxes [list $x $vorher $w 0]
        }
        set y [expr {$y + $gap}]
    }
    return [dict create y $y boxes $boxes pages $wechsel]
}

# Den Block ausfuehren.
#
# Das Skript wird im Gueltigkeitsbereich des AUFRUFERS ausgewertet -- es
# soll seine Variablen sehen (Spalten, Zeilen, Texte). Die vier Namen
# bpdf, bx, by, bw werden dort gesetzt und danach wieder auf ihren alten
# Wert gebracht, damit stack nichts hinterlaesst.
proc ::pdf4tcllib::layout::_ausfuehren {ebene script zielPdf x y w} {
    upvar $ebene bpdf bpdf bx bx by by bw bw
    foreach {n v} [list bpdf $zielPdf bx $x by $y bw $w] {
        upvar $ebene $n var
        if {[info exists var]} {
            set alt($n) $var
        }
        set var $v
    }
    set rc [catch {uplevel $ebene $script} res opts]
    foreach n {bpdf bx by bw} {
        upvar $ebene $n var
        if {[info exists alt($n)]} { set var $alt($n) } else { unset -nocomplain var }
    }
    if {$rc} { return -options $opts $res }
    return $res
}

# Die Hoehe eines Blocks, ohne ihn zu zeichnen.
# Die Hoehe eines Blocks, ohne ihn zu zeichnen.
#
# measure::block waere der naheliegende Weg, aber es wertet das Skript
# selbst eine Ebene hoeher aus -- zwei geschachtelte uplevel, und die
# Rechnung stimmt nicht mehr. Das Wegwerf-Dokument entsteht deshalb hier,
# und der Block laeuft auf DERSELBEN Ebene wie beim Zeichnen. Was
# gemessen wird, ist damit dasselbe, was gleich gezeichnet wird.
proc ::pdf4tcllib::layout::_messen {ebene script x y w paper font fill} {
    set h ""
    set mpdf [::pdf4tcl::new %AUTO% -paper $paper -orient 1]
    $mpdf startPage
    if {[llength $font] == 2} {
        catch {$mpdf setFont [lindex $font 0] [lindex $font 1]}
    }
    if {[llength $fill] == 3} { catch {$mpdf setFillColor {*}$fill} }
    set rc [catch {_ausfuehren [expr {$ebene + 1}] $script $mpdf $x $y $w} res]
    catch {$mpdf destroy}
    if {$rc} { return "" }
    if {[llength $res] == 4 && [string is double -strict [lindex $res 3]]} {
        return [lindex $res 3]
    }
    if {[string is double -strict $res]} {
        return [expr {abs($res - $y)}]
    }
    return ""
}

namespace eval ::pdf4tcllib::table {}

# ============================================================
# Oeffentliche API
# ============================================================

# Options for tagBegin Table, from a -summary that may be empty.
#
# /Summary says what the table shows and how it is built. A reader that
# cannot see the grid announces it before the cells, so someone listening
# knows what is coming instead of hearing a run of numbers.
#
# ISO 32000-1 clause 14.8.5.7; pdf4tcl takes -summary from 0.9.4.56 on.
# Older versions raise on the unknown option, which tag::begin swallows --
# the table is still tagged, only without the summary.
# --- verbundene Zellen ---------------------------------------------
#
# Eine Zelle darf statt eines Textes ein Dict sein:
#
#     [dict create text "Summe" colspan 3]
#
# Damit ueberdeckt sie drei Spalten: die Breiten werden addiert, die
# folgenden Spalten entfallen in DIESER Zeile, und das TD bekommt
# /ColSpan 3 (ISO 32000-1 Tabelle 349, Klausel 14.8.5.7). Ohne das
# Attribut ist der Baum falsch: Klausel 14.8.4.3.4 Anmerkung 2 sagt, die
# Zuordnung von Kopfzelle zu Datenzelle werde heuristisch ermittelt und
# koenne "fail for complex tables" -- eine verbundene Zelle ist genau so
# ein Fall, und ein Vorleseprogramm nennt dann die falsche Ueberschrift.
#
# ERKANNT wird die Dict-Form an der Kombination: gerade Anzahl Elemente,
# Schluessel "text" UND (colspan ODER rowspan). Eine gewoehnliche Zelle
# muesste also woertlich "text ... colspan ..." lauten, um verwechselt zu
# werden -- alles andere bleibt Text und wird unveraendert gezeichnet.
#
# rowspan kam spaeter dazu und wird von _cellRowSpan und _gridPlan
# getragen; siehe die Erklaerung dort. Hier zaehlt nur die Breite.
# Die Zelle, die in Spalte $idx BEGINNT -- und nur wenn sie dort auch
# endet. Verbundene Zellen und die von ihnen ueberdeckten Spalten liefern
# \uFFFF, damit die Breitenrechnung sie ueberspringt.
# Wieviele Spalten eine Zeile belegt -- eine Zelle mit colspan 2 zaehlt
# doppelt. Ohne das ergibt eine Kopfzeile {Region {text Zahlen colspan 2}}
# nur zwei Spalten, und die dritte faellt aus der Tabelle heraus.
# Der Belegungsplan einer Tabelle.
#
# Bei rowspan reicht die Zeile allein nicht mehr aus, um zu wissen, in
# welcher Spalte eine Zelle steht: eine Zelle aus einer frueheren Zeile
# haelt eine Spalte besetzt, und die folgende Zeile zaehlt deshalb anders
# als sie geschrieben ist. Wie in HTML laesst der Aufrufer die
# ueberdeckten Zellen einfach WEG.
#
# Geliefert wird je Zeile eine Liste von Eintraegen
#
#     {spalte colspan rowspan zelle}
#
# und zwar nur fuer die Zellen, die in DIESER Zeile beginnen.
proc ::pdf4tcllib::table::_gridPlan {rows nCols} {
    set plan {}
    array set belegt {}          ;# belegt(zeile,spalte) = 1
    set r 0
    foreach row $rows {
        set eintraege {}
        set col 0
        foreach cell $row {
            # Zur naechsten freien Spalte weiterruecken.
            while {$col < $nCols && [info exists belegt($r,$col)]} { incr col }
            if {$col >= $nCols} { break }
            set cs [_cellSpan $cell]
            set rs [_cellRowSpan $cell]
            if {$col + $cs > $nCols} { set cs [expr {$nCols - $col}] }
            lappend eintraege [list $col $cs $rs $cell]
            for {set dr 0} {$dr < $rs} {incr dr} {
                for {set dc 0} {$dc < $cs} {incr dc} {
                    set belegt([expr {$r + $dr}],[expr {$col + $dc}]) 1
                }
            }
            incr col $cs
        }
        lappend plan $eintraege
        incr r
    }
    return $plan
}

# Welche Spalten in Zeile $r von einer Zelle ueberdeckt werden, die
# WEITER unten reicht -- dort darf keine Trennlinie gezogen werden.
proc ::pdf4tcllib::table::_spannedAt {plan r} {
    set out {}
    for {set s 0} {$s <= $r} {incr s} {
        foreach e [lindex $plan $s] {
            lassign $e col cs rs
            if {$s + $rs - 1 > $r && $r >= $s} {
                for {set dc 0} {$dc < $cs} {incr dc} {
                    lappend out [expr {$col + $dc}]
                }
            }
        }
    }
    return $out
}

proc ::pdf4tcllib::table::_rowCols {row} {
    set n 0
    foreach cell $row { incr n [_cellSpan $cell] }
    return $n
}

proc ::pdf4tcllib::table::_cellAt {row idx} {
    set i 0
    foreach cell $row {
        set span [_cellSpan $cell]
        if {$i == $idx} {
            return [expr {$span > 1 ? "\uFFFF" : $cell}]
        }
        if {$idx < $i + $span} { return "\uFFFF" }
        incr i $span
    }
    return "\uFFFF"
}

# ============================================================
# group -- Zeilen gruppieren und Zwischensummen einziehen
# ============================================================
#
# Eine Liste nach einer Spalte gruppieren, je Gruppe eine Zwischensumme,
# am Ende eine Gesamtsumme. Die Rechnung ist trivial; die Arbeit ist,
# was danach kommt:
#
#   - die Zeilen muessen sortiert sein, sonst zerfaellt eine Gruppe in
#     mehrere. Das macht diese Prozedur NICHT von sich aus -- eine
#     Reihenfolge, die der Aufrufer bewusst gewaehlt hat, umzustellen
#     waere anmassend. Sie meldet es stattdessen.
#   - die Zwischensumme braucht eine Beschriftung, die ueber die
#     Textspalten reicht: das ist eine verbundene Zelle.
#   - der Aufrufer will die Summenzeilen hervorheben, muss also wissen,
#     WELCHE Zeilen das sind.
#
# Deshalb gibt group nicht nur Zeilen zurueck, sondern ein Dict:
#
#   rows        die neuen Zeilen, Zwischensummen eingefuegt
#   subtotals   die Zeilennummern der Zwischensummen
#   groups      die Zeilennummern der Gruppenkoepfe (mit -header 1)
#   total       die Zeilennummer der Gesamtsumme, oder -1
#
# Optionen:
#   -by       Spaltennummer, nach der gruppiert wird (0)
#   -sum      Liste der Spalten, die addiert werden ({})
#   -label    Beschriftung der Zwischensumme; %s wird durch den
#             Gruppenwert ersetzt ("Summe %s")
#   -total    Gesamtsumme anhaengen (1); Beschriftung -totallabel
#   -header   je Gruppe eine Kopfzeile mit dem Gruppenwert (0)
#   -blank    den Gruppenwert nur in der ersten Zeile der Gruppe
#             stehen lassen (0) -- eine Wiederholung sagt nichts
#   -strict   bei unsortierten Zeilen werfen statt zu melden (0)
#
# Nicht summierbare Werte werden uebersprungen, nicht zu 0 gemacht: ein
# leeres Feld ist keine Null, und "k.A." erst recht nicht.
proc ::pdf4tcllib::table::group {rows args} {
    array set o {
        -by 0 -sum {} -label "Summe %s" -total 1
        -totallabel "Gesamt" -header 0 -blank 0 -strict 0
    }
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "table::group: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    if {![llength $rows]} {
        return [dict create rows {} subtotals {} groups {} total -1]
    }
    set nCols [llength [lindex $rows 0]]
    if {$o(-by) < 0 || $o(-by) >= $nCols} {
        return -code error "table::group: -by $o(-by) is outside the row\
                (0..[expr {$nCols - 1}])"
    }

    # Sind die Zeilen nach der Gruppenspalte sortiert? Wenn nicht, faellt
    # eine Gruppe in mehrere Bloecke auseinander, und die Zwischensummen
    # stimmen zwar je Block, aber nicht je Gruppe.
    set gesehen {}
    set vorher "\uFFFF"
    set unsortiert 0
    foreach zeile $rows {
        set g [_cellText [lindex $zeile $o(-by)]]
        if {$g ne $vorher} {
            if {[lsearch -exact $gesehen $g] >= 0} { set unsortiert 1 ; break }
            lappend gesehen $g
            set vorher $g
        }
    }
    if {$unsortiert} {
        set text "table::group: the rows are not sorted by column\
                $o(-by); a group falls into several blocks and each gets\
                its own subtotal"
        if {$o(-strict)} { return -code error $text }
        lappend ::pdf4tcl::warnings $text
    }

    set neu {}
    set subtotals {}
    set groups {}
    set summe {}
    set gesamt {}
    foreach c $o(-sum) { dict set summe $c 0 ; dict set gesamt $c 0 }
    set aktuell "\uFFFF"
    set idx 0
    set ersteDerGruppe 1

    foreach zeile $rows {
        set g [_cellText [lindex $zeile $o(-by)]]
        if {$g ne $aktuell} {
            if {$aktuell ne "\uFFFF"} {
                lappend neu [_summenZeile $aktuell $nCols $o(-by) $summe \
                        $o(-label) $o(-sum)]
                lappend subtotals $idx
                incr idx
            }
            foreach c $o(-sum) { dict set summe $c 0 }
            set aktuell $g
            set ersteDerGruppe 1
            if {$o(-header)} {
                lappend neu [list [dict create text $g colspan $nCols]]
                lappend groups $idx
                incr idx
            }
        }
        foreach c $o(-sum) {
            set v [_cellText [lindex $zeile $c]]
            # Ein leeres Feld ist keine Null.
            if {[string is double -strict $v]} {
                dict set summe $c [expr {[dict get $summe $c] + $v}]
                dict set gesamt $c [expr {[dict get $gesamt $c] + $v}]
            }
        }
        if {$o(-blank) && !$ersteDerGruppe} {
            lset zeile $o(-by) ""
        }
        set ersteDerGruppe 0
        lappend neu $zeile
        incr idx
    }
    if {$aktuell ne "\uFFFF"} {
        lappend neu [_summenZeile $aktuell $nCols $o(-by) $summe \
                $o(-label) $o(-sum)]
        lappend subtotals $idx
        incr idx
    }
    set totalIdx -1
    if {$o(-total) && [llength $o(-sum)]} {
        lappend neu [_summenZeile "" $nCols $o(-by) $gesamt \
                $o(-totallabel) $o(-sum)]
        set totalIdx $idx
    }
    return [dict create rows $neu subtotals $subtotals groups $groups \
            total $totalIdx]
}

# Eine Summenzeile: die Beschriftung reicht ueber alle Spalten bis zur
# ersten Summenspalte, die Summen stehen in ihren eigenen Spalten.
proc ::pdf4tcllib::table::_summenZeile {gruppe nCols byCol summe label sumCols} {
    if {[string first %s $label] >= 0} {
        set text [format $label $gruppe]
    } else {
        set text $label
    }
    set erste $nCols
    foreach c $sumCols { if {$c < $erste} { set erste $c } }
    if {$erste <= 0} { set erste 1 }

    set zeile {}
    if {$erste > 1} {
        lappend zeile [dict create text $text colspan $erste]
    } else {
        lappend zeile $text
    }
    for {set c $erste} {$c < $nCols} {incr c} {
        if {[dict exists $summe $c]} {
            lappend zeile [dict get $summe $c]
        } else {
            lappend zeile ""
        }
    }
    return $zeile
}

# ============================================================
# pivot -- eine Liste zur Kreuztabelle
# ============================================================
#
# Aus Zeilen der Form {Region Quartal Umsatz} wird eine Tabelle mit den
# Regionen als Zeilen und den Quartalen als Spalten. Was die Rechnung
# nicht sagt, aber jede Kreuztabelle entscheiden muss:
#
#   - WELCHE Spalten es gibt. Sie ergeben sich aus den Daten, nicht aus
#     einer Angabe -- und ihre Reihenfolge auch: -colorder legt sie fest,
#     sonst wird sortiert. Ein Quartal, das in keiner Zeile vorkommt,
#     taucht nicht auf; wer alle vier will, gibt sie an.
#   - WAS in einer leeren Zelle steht. Eine Kreuztabelle hat fast immer
#     Luecken, und "0" ist etwas anderes als "nichts gemessen".
#     Voreinstellung ist der leere String, nicht 0.
#   - WAS bei mehreren Werten je Feld passiert. Voreinstellung ist
#     summieren; count, avg, min und max gibt es auch.
#
# Optionen:
#   -row      Spaltennummer fuer die Zeilen (0)
#   -col      Spaltennummer fuer die Spalten (1)
#   -value    Spaltennummer fuer die Werte (2)
#   -agg      sum | count | avg | min | max   (sum)
#   -empty    was in einer leeren Zelle steht ("")
#   -total    Summenspalte und Summenzeile anhaengen (1)
#   -rowlabel Titel der ersten Spalte (der Wert von -row als Text)
#   -totallabel  "Gesamt"
#   -colorder Reihenfolge der Spalten; {} = sortiert
#
# Rueckgabe: dict mit
#   header    die Kopfzeile
#   rows      die Datenzeilen
#   cols      die Spaltenwerte ohne Kopf und ohne Summenspalte
#   total     Zeilennummer der Summenzeile, oder -1
# ============================================================
# breakPoints -- wo eine Tabelle geteilt werden darf
# ============================================================
#
# Ein Layouter fragt nicht "brich um, wenn du musst", sondern "kann ich
# hier teilen, und wenn ja, wo". table::draw bricht selbst um, aber nach
# seinen eigenen Regeln, und sagt vorher nichts.
#
# Geliefert wird ein dict:
#
#   rowH        die Hoehe einer Datenzeile
#   headerH     die Hoehe der Kopfzeile (0 ohne Kopf)
#   heights     je Zeile die Hoehe VON OBEN bis einschliesslich dieser
#               Zeile, ohne Kopf
#   forbidden   Zeilennummern, VOR denen nicht geteilt werden darf
#   rows        die Anzahl der Datenzeilen
#
# Verboten ist eine Trennstelle an zwei Stellen:
#
#   - mitten in einer ueber Zeilen verbundenen Zelle. Eine solche Zelle
#     wird auf der Folgeseite NICHT wiederholt (siehe rowspan oben), also
#     waere sie nach einem Umbruch optisch zerrissen.
#   - direkt nach einer Gruppenkopfzeile. Ein Gruppenkopf allein am
#     Seitenfuss ist eine Ueberschrift ohne Inhalt; table::group liefert
#     die Nummern dieser Zeilen in "groups", und wer sie durchreicht,
#     bekommt sie hier beruecksichtigt.
#
# Die Zeilenhoehe von table::draw ist einheitlich (rowheight, sonst
# 1.8 * fontsize), Zellen werden dort nicht umbrochen -- deshalb ist die
# Rechnung eine Multiplikation und keine Messung. Fuer table::render,
# das umbricht, gilt sie nicht.
# ============================================================
# widths -- die natuerliche und die kleinste Breite
# ============================================================
#
# Ein Layouter, der Spalten verteilt, fragt zweierlei:
#
#   "Wie breit will diese Tabelle sein, wenn sie darf?"  -> natural
#   "Wie schmal geht es gerade noch?"                    -> min
#
# Dazwischen kann er verteilen; darunter nicht, ohne dass etwas
# abgeschnitten wird oder mitten im Wort umbricht.
#
# natural  ist die Breite, bei der keine Zelle umbricht: der breiteste
#          Inhalt je Spalte plus Innenabstand.
# min      ist die Breite, bei der jede Zelle noch ohne Trennung
#          umbrechen kann: das LAENGSTE WORT je Spalte plus
#          Innenabstand. Nicht die Breite eines Zeichens -- ein Wort, das
#          nicht passt, wird zeichenweise zerschnitten, und das ist keine
#          Untergrenze, sondern eine Notlage.
#
# Beide werden mit derselben Messung gerechnet wie table::draw, also mit
# $pdf, wenn es angegeben ist. Ohne $pdf schaetzt text::width ueber
# Zeichenklassen; bei einer CID-Schrift liegt das weit daneben.
#
# Rueckgabe: dict mit
#   natural       je Spalte
#   min           je Spalte
#   naturalTotal  die Summe
#   minTotal      die Summe
proc ::pdf4tcllib::table::widths {cols rows args} {
    array set o {-fontsize 9 -pad 4 -pdf {} -font {} -boldfont {}}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "table::widths: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    set fReg  $o(-font)
    set fBold $o(-boldfont)
    if {$fReg eq ""}  { set fReg  [::pdf4tcllib::fonts::fontSans] }
    if {$fBold eq ""} { set fBold [::pdf4tcllib::fonts::fontSansBold] }
    set fs  $o(-fontsize)
    set pad $o(-pad)
    set pdf $o(-pdf)

    # Die Kopfzeilen aus der Spaltenbeschreibung, wie draw sie liest.
    set headers {}
    foreach c $cols {
        set h ""
        if {[dict exists $c -header]} { set h [dict get $c -header] }
        lappend headers $h
    }
    set n [llength $cols]
    if {!$n && [llength $rows]} { set n [_rowCols [lindex $rows 0]] }

    set natural {}
    set klein {}
    for {set i 0} {$i < $n} {incr i} {
        set hd [lindex $headers $i]
        set maxNat [::pdf4tcllib::text::width $hd $fs $fBold $pdf]
        set maxMin [_wortBreite $hd $fs $fBold $pdf]
        foreach row $rows {
            set cell [_cellAt $row $i]
            if {$cell eq "\uFFFF"} { continue }
            set t [_cellText $cell]
            set w [::pdf4tcllib::text::width $t $fs $fReg $pdf]
            if {$w > $maxNat} { set maxNat $w }
            set m [_wortBreite $t $fs $fReg $pdf]
            if {$m > $maxMin} { set maxMin $m }
        }
        lappend natural [expr {$maxNat + 2 * $pad}]
        lappend klein   [expr {$maxMin + 2 * $pad}]
    }
    set nt 0.0 ; foreach w $natural { set nt [expr {$nt + $w}] }
    set mt 0.0 ; foreach w $klein   { set mt [expr {$mt + $w}] }
    return [dict create natural $natural min $klein \
            naturalTotal $nt minTotal $mt]
}

# Die Breite des laengsten Wortes -- die Untergrenze, unter der nur noch
# zeichenweise getrennt werden kann.
proc ::pdf4tcllib::table::_wortBreite {text fs font pdf} {
    set max 0
    foreach wort [split $text " \t\n"] {
        if {$wort eq ""} { continue }
        set w [::pdf4tcllib::text::width $wort $fs $font $pdf]
        if {$w > $max} { set max $w }
    }
    return $max
}

proc ::pdf4tcllib::table::breakPoints {rows args} {
    array set o {-fontsize 9 -rowheight 0 -header 1 -groups {}}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "table::breakPoints: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    set fs   $o(-fontsize)
    set rowH [expr {$o(-rowheight) > 0 ? double($o(-rowheight)) : $fs * 1.8}]
    set n    [llength $rows]
    set headerH [expr {$o(-header) ? $rowH : 0}]

    set heights {}
    set h 0
    for {set i 0} {$i < $n} {incr i} {
        set h [expr {$h + $rowH}]
        lappend heights $h
    }

    # Verbotene Trennstellen aus den verbundenen Zellen.
    set nCols 0
    if {$n} { set nCols [_rowCols [lindex $rows 0]] }
    set verboten {}
    if {$nCols} {
        set plan [_gridPlan $rows $nCols]
        set r 0
        foreach eintraege $plan {
            foreach e $eintraege {
                lassign $e col cs rs cell
                if {$rs > 1} {
                    # Vor jeder Zeile, die eine verbundene Zelle
                    # fortsetzt, darf nicht getrennt werden.
                    for {set k 1} {$k < $rs && $r + $k < $n} {incr k} {
                        lappend verboten [expr {$r + $k}]
                    }
                }
            }
            incr r
        }
    }
    # Eine Gruppenkopfzeile haelt die folgende Zeile bei sich.
    foreach g $o(-groups) {
        if {$g + 1 < $n} { lappend verboten [expr {$g + 1}] }
    }
    set verboten [lsort -integer -unique $verboten]

    return [dict create rowH $rowH headerH $headerH heights $heights \
            forbidden $verboten rows $n]
}

# Wieviele Zeilen passen in $platz Punkt Hoehe -- die Kopfzeile
# eingerechnet, verbotene Trennstellen beruecksichtigt.
#
# Rueckgabe: die Anzahl der Zeilen, die auf diese Seite duerfen. 0 heisst
# "nicht einmal die erste Zeile passt"; dann muss der Aufrufer den Platz
# vergroessern, nicht die Tabelle teilen.
#
# Wird wegen einer verbotenen Trennstelle zurueckgegangen, kann das
# Ergebnis deutlich unter dem liegen, was rechnerisch passen wuerde --
# das ist der Preis dafuer, eine verbundene Zelle nicht zu zerreissen.
proc ::pdf4tcllib::table::fitRows {platz rows args} {
    set bp [breakPoints $rows {*}$args]
    set frei [expr {$platz - [dict get $bp headerH]}]
    if {$frei <= 0} { return 0 }
    set heights   [dict get $bp heights]
    set verboten  [dict get $bp forbidden]
    set n         [dict get $bp rows]

    set passt 0
    for {set i 0} {$i < $n} {incr i} {
        if {[lindex $heights $i] > $frei} { break }
        set passt [expr {$i + 1}]
    }
    # Auf eine erlaubte Trennstelle zuruecknehmen.
    while {$passt > 0 && $passt < $n && $passt in $verboten} {
        incr passt -1
    }
    return $passt
}

proc ::pdf4tcllib::table::pivot {rows args} {
    array set o {
        -row 0 -col 1 -value 2 -agg sum -empty {}
        -total 1 -rowlabel {} -totallabel "Gesamt" -colorder {}
    }
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "table::pivot: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    if {$o(-agg) ni {sum count avg min max}} {
        return -code error "table::pivot: -agg must be sum, count, avg,\
                min or max, not \"$o(-agg)\""
    }
    if {![llength $rows]} {
        return [dict create header {} rows {} cols {} total -1]
    }

    # Sammeln: je Feld die Liste der Werte. Erst am Ende wird gerechnet,
    # damit avg und count nicht raten muessen.
    set zeilenWerte {}
    set spalten {}
    set felder [dict create]
    foreach zeile $rows {
        set rk [_cellText [lindex $zeile $o(-row)]]
        set ck [_cellText [lindex $zeile $o(-col)]]
        set v  [_cellText [lindex $zeile $o(-value)]]
        if {[lsearch -exact $zeilenWerte $rk] < 0} { lappend zeilenWerte $rk }
        if {[lsearch -exact $spalten $ck] < 0}     { lappend spalten $ck }
        dict lappend felder "$rk\u0000$ck" $v
    }

    if {[llength $o(-colorder)]} {
        set spalten $o(-colorder)
    } else {
        set spalten [lsort $spalten]
    }

    set kopf {}
    set rl $o(-rowlabel)
    if {$rl eq ""} { set rl "" }
    lappend kopf $rl
    foreach c $spalten { lappend kopf $c }
    if {$o(-total)} { lappend kopf $o(-totallabel) }

    set neu {}
    set spaltenSumme {}
    foreach c $spalten { dict set spaltenSumme $c {} }
    set gesamt {}
    foreach rk $zeilenWerte {
        set zeile [list $rk]
        set zeilenSumme {}
        foreach c $spalten {
            set key "$rk\u0000$c"
            if {[dict exists $felder $key]} {
                set werte [dict get $felder $key]
                lappend zeile [_agg $o(-agg) $werte $o(-empty)]
                foreach v $werte {
                    lappend zeilenSumme $v
                    dict lappend spaltenSumme $c $v
                    lappend gesamt $v
                }
            } else {
                # Kein Wert ist nicht dasselbe wie 0.
                lappend zeile $o(-empty)
            }
        }
        if {$o(-total)} { lappend zeile [_agg $o(-agg) $zeilenSumme $o(-empty)] }
        lappend neu $zeile
    }

    set totalIdx -1
    if {$o(-total)} {
        set zeile [list $o(-totallabel)]
        foreach c $spalten {
            lappend zeile [_agg $o(-agg) [dict get $spaltenSumme $c] $o(-empty)]
        }
        lappend zeile [_agg $o(-agg) $gesamt $o(-empty)]
        set totalIdx [llength $neu]
        lappend neu $zeile
    }
    return [dict create header $kopf rows $neu cols $spalten total $totalIdx]
}

# Ein Feld zusammenfassen. Werte, die keine Zahl sind, zaehlen nur bei
# count -- bei sum oder avg waeren sie eine erfundene Null.
proc ::pdf4tcllib::table::_agg {wie werte leer} {
    if {$wie eq "count"} { return [llength $werte] }
    set zahlen {}
    foreach v $werte {
        if {[string is double -strict $v]} { lappend zahlen $v }
    }
    if {![llength $zahlen]} { return $leer }
    switch -- $wie {
        sum { return [::tcl::mathop::+ {*}$zahlen] }
        avg { return [expr {[::tcl::mathop::+ {*}$zahlen]
                            / double([llength $zahlen])}] }
        min { return [::tcl::mathfunc::min {*}$zahlen] }
        max { return [::tcl::mathfunc::max {*}$zahlen] }
    }
    return $leer
}

proc ::pdf4tcllib::table::_isCellSpec {cell} {
    if {[llength $cell] % 2} { return 0 }
    if {[catch {dict size $cell}]} { return 0 }
    if {![dict exists $cell text]} { return 0 }
    return [expr {[dict exists $cell colspan] || [dict exists $cell rowspan]}]
}

# Wieviele Zeilen eine Zelle ueberdeckt. Wie bei colspan gilt eine
# unsinnige Angabe als eins, statt zu werfen -- eine Tabelle soll nicht
# an einer Zahl scheitern, die der Aufrufer versehentlich falsch
# geschrieben hat.
proc ::pdf4tcllib::table::_cellRowSpan {cell} {
    if {![_isCellSpec $cell]} { return 1 }
    if {![dict exists $cell rowspan]} { return 1 }
    set n [dict get $cell rowspan]
    if {![string is integer -strict $n] || $n < 1} { return 1 }
    return $n
}

proc ::pdf4tcllib::table::_cellText {cell} {
    if {[_isCellSpec $cell]} { return [dict get $cell text] }
    return $cell
}

proc ::pdf4tcllib::table::_cellSpan {cell} {
    if {![_isCellSpec $cell]} { return 1 }
    # Seit rowspan dazukam, ist eine Zellangabe auch ohne colspan gueltig.
    if {![dict exists $cell colspan]} { return 1 }
    set n [dict get $cell colspan]
    if {![string is integer -strict $n] || $n < 1} { return 1 }
    return $n
}

proc ::pdf4tcllib::table::_summaryArgs {summary} {
    if {$summary eq ""} { return {} }
    return [list -summary $summary]
}

proc ::pdf4tcllib::table::render {pdf tableData x0 yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize lineH {debug 0} {pageBreakCmd {}}} {
    # Renders a table into the PDF.
    #
    # tableData akzeptiert zwei Formate:
    #
    # 1. Listen-Format: {header aligns row1 row2 ...}
    #      header:  {Column1 column2 ...}
    #      aligns:  {left center right ...}
    #      rows:    {Wert1 Wert2 ...}
    #
    # 2. Dict-Format: {header {..} rows {{..} {..}} aligns {..} cols N}
    #      Wie of mdhelp_pdf::_extractFrameTable geliefert.
    #
    # yVar, pageNoVar: upvar-Variablen for Position and pagenzahl

    upvar $yVar y
    upvar $pageNoVar pageNo

    set fontSans     [::pdf4tcllib::fonts::fontSans]
    set fontSansBold [::pdf4tcllib::fonts::fontSansBold]

    # -- Format erkennen and normalisieren --
    if {[_isDictFormat $tableData]} {
        # Dict-Format: {header {..} rows {{..}} aligns {..}}
        set header [dict get $tableData header]
        set rows   [dict get $tableData rows]
        set aligns [dict get $tableData aligns]
    } else {
        # Listen-Format: {header aligns row1 row2 ...}
        if {[llength $tableData] < 2} { return }
        set header [lindex $tableData 0]
        set aligns [lindex $tableData 1]
        set rows   [lrange $tableData 2 end]
    }

    set nCols [_rowCols $header]
    if {$nCols == 0 && [llength $rows] > 0} {
        set nCols [_rowCols [lindex $rows 0]]
    }
    if {$nCols == 0} { return }

    set hasHdr [expr {[llength $header] > 0}]

    # -- Calculate column widths --
    set colWidths [_calcColWidths $header $aligns $rows $maxW $fontSize $fontSans $fontSansBold $pdf]
    set totalW 0
    foreach w $colWidths { set totalW [expr {$totalW + $w}] }

    set cellPad 4

    set orient [expr {$yTop < $yBot}]

    # -- Check page break (header + first data row, measured) --
    set firstRowH 0
    if {$hasHdr} {
        set firstRowH [expr {$firstRowH + \
            [_rowHeight $header $colWidths $cellPad $fontSize $fontSansBold $lineH $pdf]}]
    }
    if {[llength $rows] > 0} {
        set firstRowH [expr {$firstRowH + \
            [_rowHeight [lindex $rows 0] $colWidths $cellPad $fontSize $fontSans $lineH $pdf]}]
    }
    if {$orient ? (($y + $firstRowH) > $yBot) : (($y - $firstRowH) < $yBot)} {
        set y [_doPageBreak $pdf pageNo $pageW $pageH $margin $fontSize $orient $pageBreakCmd $yTop]
    }

    set tableStartY $y
    set rowYs [list $y]
    set hdrBottom ""

    # The whole table is one structure element, so a reader announces it as a
    # table and can navigate it by row and column rather than reading a run
    # of unrelated numbers. Does nothing when tagging is off.
    # In the dict form the caller can add a "summary" key; the list form has
    # nowhere to put one, so it stays untagged in that respect.
    set summary ""
    if {[_isDictFormat $tableData] && [dict exists $tableData summary]} {
        set summary [dict get $tableData summary]
    }
    ::pdf4tcllib::tag::begin $pdf Table {*}[_summaryArgs $summary]

    # -- Header --
    if {$hasHdr} {
        set hH [_drawHeaderRow $pdf $x0 $y $totalW $orient $colWidths $aligns \
            $cellPad $fontSize $fontSansBold $header $lineH]
        set y [expr {$orient ? ($y + $hH) : ($y - $hH)}]
        lappend rowYs $y
        set hdrBottom $y
    }

    # -- Data rows --
    $pdf setFont $fontSize $fontSans
    # Belegungsplan und Zeilenhoehen im voraus. Ohne rowspan aendert das
    # nichts; mit rowspan geht es nicht anders, weil die Hoehe einer
    # verbundenen Zelle von Zeilen abhaengt, die noch nicht gezeichnet
    # sind.
    set plan   [_gridPlan $rows $nCols]
    set hoehen [_rowHeights $plan $colWidths $cellPad $fontSize $fontSans \
            $lineH $pdf]

    set rowGaps {}
    set rowIdx 0
    foreach row $rows {
        set rH [lindex $hoehen $rowIdx]

        # Page break, measured against THIS row's real height
        if {$orient ? (($y + $rH) > $yBot) : (($y - $rH) < $yBot)} {
            _drawSegmentLines $pdf $x0 $tableStartY $y $hdrBottom $rowYs \
                    $totalW $colWidths $rowGaps
            set rowGaps {}
            set y [_doPageBreak $pdf pageNo $pageW $pageH $margin $fontSize $orient $pageBreakCmd $yTop]
            $pdf setLineWidth 0.5
            set tableStartY $y
            set rowYs [list $y]
            set hdrBottom ""
            # repeat the column header at the top of the continuation page
            if {$hasHdr} {
                set hH [_drawHeaderRow $pdf $x0 $y $totalW $orient $colWidths $aligns \
                    $cellPad $fontSize $fontSansBold $header $lineH]
                set y [expr {$orient ? ($y + $hH) : ($y - $hH)}]
                lappend rowYs $y
                set hdrBottom $y
            }
            $pdf setFont $fontSize $fontSans
        }

        # Zebra-Streifen -- decoration, so an artifact
        if {$rowIdx % 2 == 1} {
            ::pdf4tcllib::tag::artifact $pdf -type Layout
            $pdf setFillColor 0.97 0.97 0.97
            $pdf rectangle $x0 $y $totalW $rH -filled 1
            $pdf setFillColor 0.0 0.0 0.0
            ::pdf4tcllib::tag::artifactEnd $pdf
        }

        ::pdf4tcllib::tag::begin $pdf TR
        _drawPlanRow $pdf $x0 $y $orient $colWidths $aligns $cellPad \
            $fontSize $fontSans [lindex $plan $rowIdx] $hoehen $rowIdx $lineH
        ::pdf4tcllib::tag::end $pdf
        set y [expr {$orient ? ($y + $rH) : ($y - $rH)}]
        # Wo eine Zelle weiter nach unten reicht, darf keine Trennlinie
        # quer durch sie laufen. Vermerkt wird der Bereich, den die Linie
        # nach dieser Zeile aussparen muss.
        lappend rowYs $y
        lappend rowGaps [_spannedAt $plan $rowIdx]
        incr rowIdx
    }

    # -- Grid lines for the final (or only) page segment --
    _drawSegmentLines $pdf $x0 $tableStartY $y $hdrBottom $rowYs $totalW \
            $colWidths $rowGaps

    ::pdf4tcllib::tag::end $pdf

    # Reset
    $pdf setStrokeColor 0.0 0.0 0.0
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setFont $fontSize $fontSans
}

# ============================================================
# Private Helfer
# ============================================================

proc ::pdf4tcllib::table::_drawHeaderRow {pdf x0 y totalW orient colWidths aligns cellPad fontSize fontBold header lineH} {
    # Draws the header row (grey background + bold cells) at y and returns its
    # height. Used for the first page and, repeated, at the top of every
    # continuation page.
    set hH [_rowHeight $header $colWidths $cellPad $fontSize $fontBold $lineH $pdf]
    # The grey band is decoration, not content
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    $pdf setLineWidth 0.5
    $pdf setFillColor 0.88 0.88 0.88
    $pdf rectangle $x0 $y $totalW $hH -filled 1
    ::pdf4tcllib::tag::artifactEnd $pdf
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setFont $fontSize $fontBold
    ::pdf4tcllib::tag::begin $pdf TR
    _drawCellsWrapped $pdf $x0 $y $hH $orient $colWidths $aligns $cellPad \
        $fontSize $fontBold $header $lineH TH
    ::pdf4tcllib::tag::end $pdf
    return $hH
}

proc ::pdf4tcllib::table::_drawSegmentLines {pdf x0 tableStartY y hdrBottom rowYs totalW colWidths {rowGaps {}}} {
    # Draws the grid lines for one on-page table segment: top border, header
    # separator (thicker), row separators and the vertical column lines. Called
    # once per page (at each page break and once at the end) so every page of a
    # multi-page table gets a complete frame, not just the last one.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    $pdf setStrokeColor 0.6 0.6 0.6
    $pdf setLineWidth 0.5
    $pdf line $x0 $tableStartY [expr {$x0 + $totalW}] $tableStartY
    if {$hdrBottom ne ""} {
        $pdf setLineWidth 1.0
        $pdf line $x0 $hdrBottom [expr {$x0 + $totalW}] $hdrBottom
        $pdf setLineWidth 0.5
    }
    # Die Trennlinie nach jeder Zeile -- ausgespart, wo eine verbundene
    # Zelle weiter nach unten reicht. Ohne die Aussparung liefe ein Strich
    # mitten durch sie hindurch, und die Verbindung waere nur im Baum zu
    # sehen, nicht auf dem Papier.
    set i 0
    foreach ly [lrange $rowYs 2 end] {
        set luecke [lindex $rowGaps [expr {$i + 1}]]
        _drawRowLine $pdf $x0 $ly $totalW $colWidths $luecke
        incr i
    }
    _drawVLines $pdf $x0 $tableStartY $y $colWidths
    ::pdf4tcllib::tag::artifactEnd $pdf
}

# Eine waagerechte Trennlinie, unterbrochen an den Spalten in $luecke.
proc ::pdf4tcllib::table::_drawRowLine {pdf x0 ly totalW colWidths luecke} {
    if {![llength $luecke]} {
        $pdf line $x0 $ly [expr {$x0 + $totalW}] $ly
        return
    }
    set x $x0
    set start $x0
    set col 0
    foreach w $colWidths {
        if {$col in $luecke} {
            # Bis hierher zeichnen, dann die Spalte ueberspringen.
            if {$x > $start} { $pdf line $start $ly $x $ly }
            set start [expr {$x + $w}]
        }
        set x [expr {$x + $w}]
        incr col
    }
    if {$x > $start} { $pdf line $start $ly $x $ly }
}

proc ::pdf4tcllib::table::_isDictFormat {tableData} {
    # Checks whether tableData is a dict with keys header/rows/aligns.
    if {[catch {dict get $tableData rows}]} { return 0 }
    if {[catch {dict get $tableData aligns}]} { return 0 }
    return 1
}

proc ::pdf4tcllib::table::_calcColWidths {header aligns rows maxW fontSize fontSans fontSansBold {pdf {}}} {
    # Calculates column widths based on content, robust against one column
    # with occasional very long cells dominating the table:
    #   - desired = natural max width, capped at cap (no column eats the line)
    #   - floor   = header width (a header never collapses) within [absMin,cap]
    #   - distribute: grow proportionally if room, else shrink only the
    #     above-floor (flexible) portion so floors stay intact.
    set nCols [_rowCols $header]
    if {$nCols == 0 && [llength $rows] > 0} {
        set nCols [_rowCols [lindex $rows 0]]
    }
    if {$nCols == 0} { return {} }

    set pad    20
    set cap    [expr {$maxW * 0.40}]
    set absMin [expr {$fontSize * 2.0}]

    set desired {}
    set floors  {}
    for {set i 0} {$i < $nCols} {incr i} {
        set hW 0
        if {[llength $header] > 0} {
            # Wie bei den Datenzeilen: eine verbundene Kopfzelle darf
            # keine einzelne Spalte auf ihre Breite ziehen.
            set hCell [_cellAt $header $i]
            if {$hCell ne "\uFFFF"} {
                set hW [::pdf4tcllib::text::width [_cellText $hCell] \
                        $fontSize $fontSansBold $pdf]
            }
        }
        set cMax $hW
        foreach row $rows {
            # Eine verbundene Zelle steht ueber mehreren Spalten; ihre
            # Breite darf keine einzelne davon aufblaehen. Deshalb zaehlt
            # hier nur, was wirklich in Spalte $i beginnt und dort auch
            # endet.
            set cell [_cellAt $row $i]
            if {$cell eq "\uFFFF"} { continue }
            set cw [::pdf4tcllib::text::width [_cellText $cell] $fontSize \
                    $fontSans $pdf]
            if {$cw > $cMax} { set cMax $cw }
        }
        set d [expr {$cMax + $pad}]
        if {$d > $cap} { set d $cap }
        set f [expr {$hW + $pad}]
        if {$f > $cap}    { set f $cap }
        if {$f < $absMin} { set f $absMin }
        if {$d < $f}      { set d $f }
        lappend desired $d
        lappend floors  $f
    }

    set total 0.0
    foreach d $desired { set total [expr {$total + $d}] }

    set colWidths {}
    if {$total <= $maxW} {
        set extra [expr {$maxW - $total}]
        foreach d $desired {
            lappend colWidths [expr {int($d + $extra * $d / $total)}]
        }
    } else {
        set fixed 0.0
        foreach f $floors { set fixed [expr {$fixed + $f}] }
        set flex  [expr {$total - $fixed}]
        set avail [expr {$maxW - $fixed}]
        if {$flex <= 0 || $avail <= 0} {
            set sc [expr {$maxW / $total}]
            foreach d $desired { lappend colWidths [expr {int($d * $sc)}] }
        } else {
            foreach d $desired f $floors {
                lappend colWidths [expr {int($f + ($d - $f) * $avail / $flex)}]
            }
        }
    }

    return $colWidths
}

proc ::pdf4tcllib::table::_drawCells {pdf x0 y0 cellH colWidths aligns cellPad fontSize fontName texts {cellTag TD}} {
    # Draws the cells of a table row.
    set x $x0
    # Vertical centering: baseline approx. at cell center + half font height
    set textY [expr {$y0 + ($cellH + $fontSize) / 2 - 2}]

    foreach text $texts colW $colWidths align $aligns {
        set text [::pdf4tcllib::unicode::sanitize $text]
        set availW [expr {$colW - 2 * $cellPad}]

        if {$align eq "center"} {
            set tw [::pdf4tcllib::text::width $text $fontSize $fontName $pdf]
            set textX [expr {$x + ($colW - $tw) / 2.0}]
        } elseif {$align eq "right"} {
            set tw [::pdf4tcllib::text::width $text $fontSize $fontName $pdf]
            set textX [expr {$x + $colW - $cellPad - $tw}]
        } else {
            set textX [expr {$x + $cellPad}]
        }

        set text [::pdf4tcllib::text::truncate $text $availW $fontSize $fontName $pdf]
        if {$cellTag eq "TH"} {
            ::pdf4tcllib::tag::begin $pdf TH -scope Column
        } else {
            ::pdf4tcllib::tag::begin $pdf TD
        }
        ::pdf4tcllib::unicode::safeText $pdf $text -x $textX -y $textY
        ::pdf4tcllib::tag::end $pdf
        set x [expr {$x + $colW}]
    }
}

# Die Hoehe jeder Zeile, im voraus und fuer die ganze Tabelle.
#
# Ohne rowspan waere das je Zeile fuer sich zu rechnen. Mit rowspan nicht:
# eine Zelle ueber drei Zeilen braucht so viel Platz, wie die drei
# zusammen hergeben -- reicht das nicht, muss die LETZTE der drei
# wachsen, sonst steht der Text ueber der Trennlinie.
proc ::pdf4tcllib::table::_rowHeights {plan colWidths cellPad fontSize fontName lineH pdf} {
    set n [llength $plan]
    set hoehen {}
    # Erster Durchgang: nur Zellen, die eine einzige Zeile belegen.
    for {set r 0} {$r < $n} {incr r} {
        set maxLines 1
        foreach e [lindex $plan $r] {
            lassign $e col cs rs cell
            if {$rs != 1} { continue }
            set colW [_spanWidth $colWidths $col $cs]
            if {$colW <= 0} { continue }
            set availW [expr {$colW - 2 * $cellPad}]
            set k [llength [::pdf4tcllib::text::wrap [_cellText $cell] \
                    $availW $fontSize $fontName 0 $pdf 1]]
            if {$k > $maxLines} { set maxLines $k }
        }
        lappend hoehen [expr {$maxLines * $lineH + 2 * $cellPad}]
    }
    # Zweiter Durchgang: was die verbundenen Zellen zusaetzlich brauchen.
    for {set r 0} {$r < $n} {incr r} {
        foreach e [lindex $plan $r] {
            lassign $e col cs rs cell
            if {$rs < 2} { continue }
            set colW [_spanWidth $colWidths $col $cs]
            if {$colW <= 0} { continue }
            set availW [expr {$colW - 2 * $cellPad}]
            set k [llength [::pdf4tcllib::text::wrap [_cellText $cell] \
                    $availW $fontSize $fontName 0 $pdf 1]]
            set noetig [expr {$k * $lineH + 2 * $cellPad}]
            set letzte [expr {$r + $rs - 1}]
            if {$letzte >= $n} { set letzte [expr {$n - 1}] }
            set da 0
            for {set i $r} {$i <= $letzte} {incr i} {
                set da [expr {$da + [lindex $hoehen $i]}]
            }
            if {$noetig > $da} {
                lset hoehen $letzte [expr {[lindex $hoehen $letzte]
                        + $noetig - $da}]
            }
        }
    }
    return $hoehen
}

# Die Breite von $cs Spalten ab Spalte $col.
proc ::pdf4tcllib::table::_spanWidth {colWidths col cs} {
    set w 0
    for {set k 0} {$k < $cs && $col + $k < [llength $colWidths]} {incr k} {
        set w [expr {$w + [lindex $colWidths [expr {$col + $k}]]}]
    }
    return $w
}

proc ::pdf4tcllib::table::_rowHeight {row colWidths cellPad fontSize fontName lineH pdf} {
    # Measures the height a row needs once each cell is wrapped (hardBreak on)
    # to its inner column width: max wrapped line count over the cells.
    set maxLines 1
    set i 0
    foreach cell $row {
        set span [_cellSpan $cell]
        # Eine verbundene Zelle hat mehr Platz, bricht also spaeter um --
        # wer hier nur die erste Spaltenbreite naehme, machte die Zeile zu
        # hoch.
        set colW 0
        for {set k 0} {$k < $span && $i + $k < [llength $colWidths]} {incr k} {
            set colW [expr {$colW + [lindex $colWidths [expr {$i + $k}]]}]
        }
        incr i $span
        if {$colW <= 0} { continue }
        set availW [expr {$colW - 2 * $cellPad}]
        set n [llength [::pdf4tcllib::text::wrap [_cellText $cell] $availW \
                $fontSize $fontName 0 $pdf 1]]
        if {$n > $maxLines} { set maxLines $n }
    }
    return [expr {$maxLines * $lineH + 2 * $cellPad}]
}

# Eine Zeile nach Belegungsplan zeichnen.
#
# Anders als _drawCellsWrapped bekommt diese Fassung die Eintraege mit
# ihrer Spalte, ihrer Spanne und ihrer Hoehe -- eine ueber mehrere Zeilen
# verbundene Zelle wird EINMAL gezeichnet, in der Zeile, in der sie
# beginnt, und reicht dann ueber die folgenden Baender.
proc ::pdf4tcllib::table::_drawPlanRow {pdf x0 y orient colWidths aligns cellPad
        fontSize fontName eintraege hoehen r lineH {cellTag TD}} {
    foreach e $eintraege {
        lassign $e col cs rs cell
        set colW [_spanWidth $colWidths $col $cs]
        if {$colW <= 0} { continue }
        # Hoehe: die eigene Zeile, plus die weiteren, die sie ueberdeckt.
        set h 0
        for {set i $r} {$i < $r + $rs && $i < [llength $hoehen]} {incr i} {
            set h [expr {$h + [lindex $hoehen $i]}]
        }
        set x [expr {$x0 + [_spanWidth $colWidths 0 $col]}]
        set align [lindex $aligns $col]
        if {$align eq ""} { set align left }

        set spanArgs {}
        if {$cs > 1} { lappend spanArgs -colspan $cs }
        if {$rs > 1} { lappend spanArgs -rowspan $rs }
        if {$cellTag eq "TH"} {
            ::pdf4tcllib::tag::begin $pdf TH -scope Column {*}$spanArgs
        } else {
            ::pdf4tcllib::tag::begin $pdf TD {*}$spanArgs
        }
        set availW [expr {$colW - 2 * $cellPad}]
        set lines [::pdf4tcllib::text::wrap [_cellText $cell] $availW \
                $fontSize $fontName 0 $pdf 1]
        if {$orient} {
            set base [expr {$y + $cellPad + $fontSize}] ; set step $lineH
        } else {
            set base [expr {$y + $h - $cellPad - $fontSize}]
            set step [expr {-$lineH}]
        }
        foreach ln $lines {
            set ln [::pdf4tcllib::unicode::sanitize $ln]
            if {$align eq "center"} {
                set tw [::pdf4tcllib::text::width $ln $fontSize $fontName $pdf]
                set tx [expr {$x + ($colW - $tw) / 2.0}]
            } elseif {$align eq "right"} {
                set tw [::pdf4tcllib::text::width $ln $fontSize $fontName $pdf]
                set tx [expr {$x + $colW - $cellPad - $tw}]
            } else {
                set tx [expr {$x + $cellPad}]
            }
            ::pdf4tcllib::unicode::safeText $pdf $ln -x $tx -y $base
            set base [expr {$base + $step}]
        }
        ::pdf4tcllib::tag::end $pdf
    }
}

proc ::pdf4tcllib::table::_drawCellsWrapped {pdf x0 y rowH orient colWidths aligns cellPad fontSize fontName texts lineH {cellTag TD}} {
    # cellTag is TH for the header row, TD otherwise. Header cells also carry
    # /Scope Column: ISO 14289-1 clause 7.5 wants it wherever the relation
    # between a header and its data cells cannot be derived from the layout,
    # which is the case for any table with a single header row.
    # Draws one table row with per-cell wrapping (hardBreak on) and alignment,
    # top-aligned within the row band. Honours the orient flag so it works in
    # both top-left (orient=1) and bottom-left (orient=0) coordinate systems.
    set x $x0
    set i 0
    foreach cell $texts {
        set text [_cellText $cell]
        set span [_cellSpan $cell]
        # Die Breite einer verbundenen Zelle ist die Summe der Spalten,
        # die sie ueberdeckt; die Ausrichtung kommt von der ersten.
        set colW 0
        for {set k 0} {$k < $span && $i + $k < [llength $colWidths]} {incr k} {
            set colW [expr {$colW + [lindex $colWidths [expr {$i + $k}]]}]
        }
        set align [lindex $aligns $i]
        if {$align eq ""} { set align left }
        incr i $span
        if {$colW <= 0} { continue }
        set spanArgs {}
        if {$span > 1} { set spanArgs [list -colspan $span] }
        if {$cellTag eq "TH"} {
            ::pdf4tcllib::tag::begin $pdf TH -scope Column {*}$spanArgs
        } else {
            ::pdf4tcllib::tag::begin $pdf TD {*}$spanArgs
        }
        set availW [expr {$colW - 2 * $cellPad}]
        set lines [::pdf4tcllib::text::wrap $text $availW $fontSize $fontName 0 $pdf 1]
        if {$orient} {
            set base [expr {$y + $cellPad + $fontSize}] ; set step $lineH
        } else {
            set base [expr {$y + $rowH - $cellPad - $fontSize}] ; set step [expr {-$lineH}]
        }
        foreach ln $lines {
            set ln [::pdf4tcllib::unicode::sanitize $ln]
            if {$align eq "center"} {
                set tw [::pdf4tcllib::text::width $ln $fontSize $fontName $pdf]
                set tx [expr {$x + ($colW - $tw) / 2.0}]
            } elseif {$align eq "right"} {
                set tw [::pdf4tcllib::text::width $ln $fontSize $fontName $pdf]
                set tx [expr {$x + $colW - $cellPad - $tw}]
            } else {
                set tx [expr {$x + $cellPad}]
            }
            ::pdf4tcllib::unicode::safeText $pdf $ln -x $tx -y $base
            set base [expr {$base + $step}]
        }
        ::pdf4tcllib::tag::end $pdf
        set x [expr {$x + $colW}]
    }
}

proc ::pdf4tcllib::table::_drawVLines {pdf x0 yStart yEnd colWidths} {
    # Draws vertikale Trennlinien.
    set x $x0
    $pdf line $x $yStart $x $yEnd
    foreach colW $colWidths {
        set x [expr {$x + $colW}]
        $pdf line $x $yStart $x $yEnd
    }
}

proc ::pdf4tcllib::table::_doPageBreak {pdf pageNoVar pageW pageH margin fontSize orient pageBreakCmd yTop} {
    # Performs a page break during table rendering and returns the new top y.
    #
    # If pageBreakCmd is non-empty the host owns pagination: the callback is
    # evaluated at global scope and must finish the current page (footer),
    # start the next one (header), advance the host's own page counter and
    # return the new top y. table::render then continues from that y and does
    # NOT touch pageNoVar. This keeps a host's header/footer template
    # consistent across table-spanning page breaks.
    #
    # If pageBreakCmd is empty the legacy internal break is used (writes a
    # "- N -" marker via _pageBreak and returns yTop). Behaviour unchanged.
    upvar $pageNoVar pageNo
    if {$pageBreakCmd ne ""} {
        set newY [uplevel #0 $pageBreakCmd]
        if {$newY eq ""} { set newY $yTop }
        return $newY
    }
    _pageBreak $pdf pageNo $pageW $pageH $margin $fontSize $orient
    return $yTop
}

proc ::pdf4tcllib::table::_pageBreak {pdf pageNoVar pageW pageH margin fontSize {orient 0}} {
    # Page break. orient: 1=top-left, 0=bottom-left
    upvar $pageNoVar pageNo
    set fontSans [::pdf4tcllib::fonts::fontSans]
    set y [expr {$orient ? ($pageH - $margin * 0.5) : ($margin * 0.5)}]
    set x [expr {$pageW - $margin}]
    $pdf setFont [expr {$fontSize - 2}] $fontSans
    ::pdf4tcllib::unicode::safeText $pdf "- $pageNo -" -x $x -y $y -align right
    $pdf endPage
    incr pageNo
    $pdf startPage
}

# Rejects an option the caller made up. Without this, `array set opts $args`
# accepts every key: a typo, a renamed option or an option this version does
# not implement is silently stored and never read. Measured 2026-08-15:
# `-quatsch 1` went through pdf4tcltable::render without a word.
proc ::pdf4tcllib::table::_checkOpts {who defaults args_} {
    if {[llength $args_] % 2} {
        return -code error "$who: expected an even number of option/value words"
    }
    foreach {key val} $args_ {
        if {![dict exists $defaults $key]} {
            return -code error \
                "$who: unknown option $key (allowed: [join [lsort [dict keys $defaults]] { }])"
        }
    }
}

proc ::pdf4tcllib::table::simpleTable {pdf x y col_widths rows args} {
    # Simple table with column widths and row lists.
    # For testitpdf examples. For complex tables: table::render.
    #
    # Argumente:
    #   col_widths  List of column widths in points
    #   rows        List of rows, each row a list of cell texts
    #   -zebra 0/1  Zebra-Streifen
    #   -pad N      Cell padding (default: 5)
    #   -header_bg  RGB list for header (default: {0.9 0.9 0.9})
    #   -row_height Row height (default: 20)
    #   -font_size  Font size (default: 10)
    #
    # Returns the next Y position.

    array set opts {
        -zebra 0
        -pad 5
        -header_bg {0.9 0.9 0.9}
        -row_height 20
        -font_size 10
        -summary {}
    }
    _checkOpts ::pdf4tcllib::table::simpleTable [array get opts] $args
    array set opts $args

    set num_cols [llength $col_widths]
    set num_rows [llength $rows]
    set row_height $opts(-row_height)
    set pad $opts(-pad)

    # Total width
    set table_w 0
    foreach w $col_widths { set table_w [expr {$table_w + $w}] }

    # Zebra stripes, header background and grid lines are decoration: they
    # separate visually and mean nothing on their own. Tagged as content a
    # reader announces every rule as if it carried information.
    ::pdf4tcllib::tag::artifact $pdf -type Layout

    if {$opts(-zebra)} {
        for {set r 0} {$r < $num_rows} {incr r} {
            if {$r % 2 == 1} {
                set row_y [expr {$y + $r * $row_height}]
                $pdf setFillColor 0.95 0.95 0.95
                $pdf rectangle $x $row_y $table_w $row_height -filled 1
                $pdf setFillColor 0 0 0
            }
        }
    }

    # Header background (first row)
    if {[llength $opts(-header_bg)] == 3} {
        lassign $opts(-header_bg) r g b
        $pdf setFillColor $r $g $b
        $pdf rectangle $x $y $table_w $row_height -filled 1
        $pdf setFillColor 0 0 0
    }

    # Grid lines
    $pdf setLineWidth 0.5
    for {set r 0} {$r <= $num_rows} {incr r} {
        set line_y [expr {$y + $r * $row_height}]
        $pdf line $x $line_y [expr {$x + $table_w}] $line_y
    }
    set col_x $x
    $pdf line $col_x $y $col_x [expr {$y + $num_rows * $row_height}]
    foreach w $col_widths {
        set col_x [expr {$col_x + $w}]
        $pdf line $col_x $y $col_x [expr {$y + $num_rows * $row_height}]
    }

    ::pdf4tcllib::tag::artifactEnd $pdf

    # Cell contents. table::render and table::draw have carried a logical
    # structure since 0.6; this one did not, so a reader got a run of
    # unrelated strings where the other two give a navigable table.
    #
    # The first row is the header -- that is what -header_bg paints. Its
    # cells are TH with /Scope Column, which ISO 14289-1 clause 7.5 asks
    # for wherever the relation between header and data cell does not
    # follow from the layout, and with a single header row it never does.
    #
    # Only tagged when there is something to tag: since pdf4tcl 0.9.4.43 a
    # Table has to hold a row and a TR has to hold a cell, so an empty
    # table would be refused at tagEnd.
    set doTag [expr {$num_rows > 0 && $num_cols > 0}]
    set hasHeader [expr {[llength $opts(-header_bg)] == 3}]

    if {$doTag} {
        ::pdf4tcllib::tag::begin $pdf Table {*}[_summaryArgs $opts(-summary)]
    }
    $pdf setFont $opts(-font_size) [::pdf4tcllib::_defaultFamily]
    for {set r 0} {$r < $num_rows} {incr r} {
        set row [lindex $rows $r]
        set text_y [expr {$y + $r * $row_height + $row_height/2 + $opts(-font_size)/3}]
        set col_x $x
        if {$doTag} { ::pdf4tcllib::tag::begin $pdf TR }
        for {set c 0} {$c < $num_cols} {incr c} {
            set cell_text [lindex $row $c]
            if {$doTag} {
                if {$hasHeader && $r == 0} {
                    ::pdf4tcllib::tag::begin $pdf TH -scope Column
                } else {
                    ::pdf4tcllib::tag::begin $pdf TD
                }
            }
            $pdf text $cell_text -x [expr {$col_x + $pad}] -y $text_y
            if {$doTag} { ::pdf4tcllib::tag::end $pdf }
            set col_x [expr {$col_x + [lindex $col_widths $c]}]
        }
        if {$doTag} { ::pdf4tcllib::tag::end $pdf }
    }
    if {$doTag} { ::pdf4tcllib::tag::end $pdf }

    return [expr {$y + $num_rows * $row_height + $pad}]
}


# ================================================================
# table::draw -- ergonomischer Aufsatz (Tk-frei). Additiv.
# ================================================================

# pdf4tcllib::table::draw -- an ergonomic, Tk-free, data-driven table
# renderer on top of the existing engine (fonts/text/unicode).
# It complements table::render and simpleTable without changing them.
#
#   ::pdf4tcllib::table::draw pdf x y cols data ?option value ...?
#
#   cols   per column {-header "Text" -width auto|<pt> -align l|c|r -font reg|bold|italic|mono}
#   data   list of rows; each row a list of plain cell strings
#
#   Options:
#     -ctx <dict>       page::context -> automatic page break, header per page
#     -maxwidth <pt>    otherwise from -ctx text_w, otherwise 480
#     -header 0|1       header row (default 1)
#     -headerbg {r g b} / -headerfg {r g b}
#     -zebra 0|1 + -zebracolor {r g b} + -zebrastart 0|1 (phase offset)
#     -fontsize -pad -border 0|1 -rowheight (0 = 1.8*fontsize)
#     -cellstyles {R,C {-bg {r g b} -fg {r g b} -font bold -align right} ...}
#     -rowstyles  {R {-bg .. -fg .. -font ..} ...}
#     -rowindent  {R <pt> ...}   indent the first column of a row (tree mode)
#     -footer {values...}        bold closing row; -footerbg {r g b} -footerbold 0|1
#     -yvar / -pagevar    write the position and page counter back
#     -orient 0|1 -pagebreakcmd <cmd>
#
#   Precedence of background and style:  cell > row > zebra
#   Lines and baselines reproduce the look of pdf4tcltable 0.2.
#   Returns: the next y position.


# The face for a keyword. $ovr overrides individual faces
# ({reg NAME bold NAME ...}); empty means the set loaded by fonts::init.
# The override exists because the tablelist adapter offers -font/-boldfont;
# without it those two options were accepted and never applied.
proc ::pdf4tcllib::table::_dwFont {which {ovr {}}} {
    if {[dict exists $ovr $which] && [dict get $ovr $which] ne ""} {
        return [dict get $ovr $which]
    }
    switch -- $which {
        bold       { return [::pdf4tcllib::fonts::fontSansBold] }
        italic     { return [::pdf4tcllib::fonts::fontSansItalic] }
        bolditalic { return [::pdf4tcllib::fonts::fontSansBoldItalic] }
        mono       { return [::pdf4tcllib::fonts::fontMono] }
        default    { return [::pdf4tcllib::fonts::fontSans] }
    }
}

proc ::pdf4tcllib::table::_dwFill {pdf x y w h rgb} {
    # Background fills are decoration. Marked as an artifact so a reader does
    # not announce them; does nothing when tagging is off.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    lassign $rgb r g b
    $pdf setFillColor $r $g $b
    $pdf rectangle $x $y $w $h -filled 1 -stroke 0
    $pdf setFillColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
}

# Resolve the column widths: auto = content width (header bold, cells
# regular, first column including its indent); fixed ones in points; if the
# sum exceeds maxW, scale down.
proc ::pdf4tcllib::table::_dwWidths {pdf wspec headers data aligns fs fReg fBold pad maxW rowindent} {
    set widths {}
    set i 0
    foreach w $wspec hd $headers {
        if {$w eq "auto"} {
            set mw [::pdf4tcllib::text::width $hd $fs $fBold $pdf]
            set r 0
            foreach row $data {
                # Wie in _calcColWidths: eine verbundene Zelle steht ueber
                # mehreren Spalten und darf keine einzelne davon auf ihre
                # Breite ziehen.
                set cell [_cellAt $row $i]
                if {$cell eq "\uFFFF"} { incr r ; continue }
                set cw [::pdf4tcllib::text::width [_cellText $cell] $fs \
                        $fReg $pdf]
                if {$i == 0 && [dict exists $rowindent $r]} {
                    set cw [expr {$cw + [dict get $rowindent $r]}]
                }
                if {$cw > $mw} { set mw $cw }
                incr r
            }
            lappend widths [expr {$mw + 2 * $pad}]
        } else {
            lappend widths [expr {double($w)}]
        }
        incr i
    }
    set total 0.0
    foreach w $widths { set total [expr {$total + $w}] }
    if {$total > $maxW && $total > 0} {
        set f [expr {double($maxW) / $total}]
        set scaled {}
        foreach w $widths { lappend scaled [expr {$w * $f}] }
        return $scaled
    }
    return $widths
}

# One cell: optional background plus text on the baseline (curY+rowH-pad),
# aligned by pdf4tcl itself, as in 0.2. Draws NO lines.
proc ::pdf4tcllib::table::_dwCell {pdf cx y cw rowH value colAlign colFont fs pad style {indent 0} {ovr {}}} {
    array set st {-bg {} -fg {} -font {} -align {} -notruncate 0}
    array set st $style
    set al   [expr {$st(-align) ne "" ? $st(-align) : $colAlign}]
    set fw   [expr {$st(-font)  ne "" ? $st(-font)  : $colFont}]
    set font [_dwFont $fw $ovr]
    if {$st(-bg) ne ""} { _dwFill $pdf $cx $y $cw $rowH $st(-bg) }
    set value  [::pdf4tcllib::unicode::sanitize $value]
    set availW [expr {$cw - 2 * $pad - $indent}]
    # -notruncate: Werte, die nicht gekuerzt werden duerfen.
    #
    # Fuer Bemerkungen und Modellnamen ist die Kuerzung mit "..." richtig
    # -- ein langer Name soll die Spalte nicht sprengen. Fuer Werte, die
    # abgetippt werden muessen (Kennwoerter, Schluessel, Pruefsummen), ist
    # sie falsch: das Blatt sieht richtig aus und ist es nicht.
    #
    # Gemessen 14.09.2026: gekuerzt wird nach BREITE, nicht nach
    # Zeichenzahl -- 24 Zeichen in Versalien fielen weg, 29 gemischte
    # nicht. Wer die Laenge im Blick behaelt, uebersieht es.
    if {!$st(-notruncate)} {
        set value [::pdf4tcllib::text::truncate $value $availW $fs $font $pdf]
    }
    set bl [expr {$y + $rowH - $pad}]
    if {$st(-fg) ne ""} { lassign $st(-fg) r g b; $pdf setFillColor $r $g $b }
    $pdf setFont $fs $font
    switch -- $al {
        right  { ::pdf4tcllib::unicode::safeText $pdf $value \
                     -x [expr {$cx + $cw - $pad}] -y $bl -align right }
        center { ::pdf4tcllib::unicode::safeText $pdf $value \
                     -x [expr {$cx + $cw / 2.0}] -y $bl -align center }
        default { ::pdf4tcllib::unicode::safeText $pdf $value \
                     -x [expr {$cx + $pad + $indent}] -y $bl }
    }
    $pdf setFillColor 0 0 0
}

# The inner vertical lines of a row, not the outer edges.
proc ::pdf4tcllib::table::_dwInnerV {pdf x y rowH colW rgb lw} {
    lassign $rgb r g b
    $pdf setStrokeColor $r $g $b
    $pdf setLineWidth $lw
    set cx $x
    set n [llength $colW]
    set i 0
    foreach w $colW {
        if {$i < $n - 1} {
            $pdf line [expr {$cx + $w}] $y [expr {$cx + $w}] [expr {$y + $rowH}]
        }
        set cx [expr {$cx + $w}]
        incr i
    }
    $pdf setStrokeColor 0 0 0
    $pdf setLineWidth 1
}

# Kopfzeile (0.2-Optik: bg, eigener Rahmen 0.45/0.6, innere V-Linien 0.6/0.3).
proc ::pdf4tcllib::table::_dwHead {pdf x y totalW colW aligns headers fBold fs pad headbg headfg rowH border} {
    _dwFill $pdf $x $y $totalW $rowH $headbg
    if {$border} {
        $pdf setStrokeColor 0.45 0.45 0.45
        $pdf setLineWidth 0.6
        $pdf rectangle $x $y $totalW $rowH
        $pdf setStrokeColor 0 0 0
        $pdf setLineWidth 1
    }
    lassign $headfg hr hg hb
    set bl [expr {$y + $rowH - $pad}]
    set cx $x
    ::pdf4tcllib::tag::begin $pdf TR
    foreach h $headers cw $colW al $aligns {
        # /Scope Column: ISO 14289-1 clause 7.5 wants it where the relation
        # between a header and its data cells is not derivable from the
        # layout, which is the case for a single header row.
        ::pdf4tcllib::tag::begin $pdf TH -scope Column
        set h [::pdf4tcllib::unicode::sanitize $h]
        set h [::pdf4tcllib::text::truncate $h [expr {$cw - 2 * $pad}] $fs $fBold $pdf]
        $pdf setFillColor $hr $hg $hb
        $pdf setFont $fs $fBold
        switch -- $al {
            right  { ::pdf4tcllib::unicode::safeText $pdf $h \
                         -x [expr {$cx + $cw - $pad}] -y $bl -align right }
            center { ::pdf4tcllib::unicode::safeText $pdf $h \
                         -x [expr {$cx + $cw / 2.0}] -y $bl -align center }
            default { ::pdf4tcllib::unicode::safeText $pdf $h \
                         -x [expr {$cx + $pad}] -y $bl }
        }
        $pdf setFillColor 0 0 0
        ::pdf4tcllib::tag::end $pdf
        set cx [expr {$cx + $cw}]
    }
    ::pdf4tcllib::tag::end $pdf
    if {$border} { _dwInnerV $pdf $x $y $rowH $colW {0.6 0.6 0.6} 0.3 }
    return [expr {$y + $rowH}]
}

proc ::pdf4tcllib::table::draw {pdf x y cols data args} {
    array set o {
        -ctx {} -maxwidth {} -header 1 -zebra 0 -zebracolor {0.95 0.95 0.95}
        -zebrastart 0 -headerbg {0.89 0.92 0.95} -headerfg {0 0 0}
        -fontsize 9 -pad 4 -border 1 -rowheight 0
        -cellstyles {} -rowstyles {} -rowindent {} -yvar {} -pagevar {}
        -orient {} -pagebreakcmd {}
        -footer {} -footerbg {0.90 0.90 0.90} -footerbold 1
        -fontreg {} -fontbold {} -summary {}
    }
    array set o $args
    # Die Richtung kennt das Dokument selbst; sie hier noch einmal
    # anzugeben ist eine Fehlerquelle. text::writeParagraph fragt seit
    # jeher das Objekt ($pdf cget -orient); draw verlangte sie als Option
    # mit der Vorgabe 1, und auf einem Dokument mit -orient 0 stand die
    # Tabelle damit auf dem Kopf, ohne dass jemand etwas sagte.
    #
    # Eine ausdrueckliche Angabe gewinnt weiterhin; sie wird nur nicht
    # mehr verlangt.
    if {$o(-orient) eq ""} {
        set o(-orient) 1
        catch {set o(-orient) [$pdf cget -orient]}
    }
    # -orient 0 wird abgelehnt, nicht halb bedient.
    #
    # Die Option steuert hier nur den Seitenumbruch, nicht die Richtung,
    # in der die Zeilen laufen: unter -orient 0 waechst die Tabelle nach
    # OBEN, die Kopfzeile steht unten. Gemessen an einem Dreizeiler bei
    # y=100 -- Kopf auf PDF-y 112, die Zeilen darueber bei 128 und 144.
    #
    # Das liesse sich in draw geradeziehen (rund zehn Stellen rechnen mit
    # y + rowH). Es wuerde aber nur die halbe Kette richten: page::context
    # liefert top und bottom von OBEN gemessen, und daran haengen der
    # Seitenumbruch hier, page::header, page::footer, flow::columns und
    # toc. Die Zeilen liefen dann richtig und der Umbruch gegen eine
    # Grenze, die das Gegenteil bedeutet.
    #
    # Eine Bibliothek, die weiss, dass sie falsch zeichnet, sollte es
    # nicht trotzdem tun. Wer -orient 0 wirklich braucht, meldet sich --
    # dann ist auch bekannt, was er sonst noch benutzt.
    if {!$o(-orient)} {
        return -code error "table::draw: -orient 0 is not supported.\
                The rows would grow upwards and the header would end up\
                at the bottom, because page::context measures top and\
                bottom from the top of the page. Create the document\
                with -orient 1 (the pdf4tcl default), or pass -orient 1\
                here if you know what you are doing."
    }

    set ctx $o(-ctx)
    set haveCtx [expr {$ctx ne ""}]
    if {$o(-maxwidth) eq ""} {
        set o(-maxwidth) [expr {$haveCtx ? [dict get $ctx text_w] : 480}]
    }
    set fs   $o(-fontsize)
    set pad  $o(-pad)
    set rowH [expr {$o(-rowheight) > 0 ? double($o(-rowheight)) : $fs * 1.8}]
    # Face override: empty means the set from fonts::init.
    set fontOvr {}
    if {$o(-fontreg)  ne ""} { dict set fontOvr reg  $o(-fontreg) }
    if {$o(-fontbold) ne ""} { dict set fontOvr bold $o(-fontbold) }
    set fReg  [_dwFont reg  $fontOvr]
    set fBold [_dwFont bold $fontOvr]

    # cols normalisieren
    set headers {}; set aligns {}; set colFonts {}; set wspec {}
    set colNoTrunc {}
    foreach c $cols {
        array unset cc
        array set cc {-header {} -width auto -align left -font reg -notruncate 0}
        array set cc $c
        lappend headers  $cc(-header)
        lappend aligns   $cc(-align)
        lappend colFonts $cc(-font)
        lappend wspec    $cc(-width)
        lappend colNoTrunc $cc(-notruncate)
    }
    set colW [_dwWidths $pdf $wspec $headers $data $aligns $fs $fReg $fBold $pad $o(-maxwidth) $o(-rowindent)]
    set totalW 0.0
    foreach w $colW { set totalW [expr {$totalW + $w}] }

    if {$o(-yvar) ne ""} { upvar 1 $o(-yvar) yout }
    if {$o(-pagevar) ne ""} {
        upvar 1 $o(-pagevar) pageNo
    } else {
        set pageNo 1
    }

    if {$haveCtx} {
        set yTop   [dict get $ctx top]
        set yBot   [dict get $ctx bottom]
        set pageW  [dict get $ctx page_w]
        set pageH  [dict get $ctx page_h]
        set margin [dict get $ctx margin]
    }

    set segTop $y
    # One structure element for the whole table, so a reader can navigate it
    # by row and column instead of reading a run of unrelated values.
    ::pdf4tcllib::tag::begin $pdf Table {*}[_summaryArgs $o(-summary)]

    if {$o(-header)} {
        set y [_dwHead $pdf $x $y $totalW $colW $aligns $headers $fBold $fs $pad \
                   $o(-headerbg) $o(-headerfg) $rowH $o(-border)]
    }
    set cellstyles $o(-cellstyles)
    set rowstyles  $o(-rowstyles)
    set rowindent  $o(-rowindent)

    set r 0
    foreach row $data {
        # Seitenumbruch?
        if {$haveCtx && ($y + $rowH) > $yBot} {
            if {$o(-border)} {
                $pdf setStrokeColor 0.45 0.45 0.45; $pdf setLineWidth 0.6
                $pdf rectangle $x $segTop $totalW [expr {$y - $segTop}]
                $pdf setStrokeColor 0 0 0; $pdf setLineWidth 1
            }
            set y [::pdf4tcllib::table::_doPageBreak $pdf pageNo $pageW $pageH \
                       $margin $fs $o(-orient) $o(-pagebreakcmd) $yTop]
            set segTop $y
            if {$o(-header)} {
                set y [_dwHead $pdf $x $y $totalW $colW $aligns $headers $fBold $fs $pad \
                           $o(-headerbg) $o(-headerfg) $rowH $o(-border)]
            }
        }
        # Top rule of the row (0.78/0.3)
        if {$o(-border)} {
            $pdf setStrokeColor 0.78 0.78 0.78; $pdf setLineWidth 0.3
            $pdf line $x $y [expr {$x + $totalW}] $y
            $pdf setStrokeColor 0 0 0; $pdf setLineWidth 1
        }
        # Zeilen-Hintergrund
        array unset rs
        array set rs {-bg {} -fg {} -font {}}
        if {[dict exists $rowstyles $r]} { array set rs [dict get $rowstyles $r] }
        if {$rs(-bg) ne ""} {
            _dwFill $pdf $x $y $totalW $rowH $rs(-bg)
        } elseif {$o(-zebra) && (($r + $o(-zebrastart)) % 2 == 1)} {
            _dwFill $pdf $x $y $totalW $rowH $o(-zebracolor)
        }
        # Zellen + Einrueckung
        set ind 0
        if {[dict exists $rowindent $r]} { set ind [dict get $rowindent $r] }
        set cx $x
        set c 0
        ::pdf4tcllib::tag::begin $pdf TR
        # Verbundene Zellen wie in table::render: eine Zelle darf ein
        # Dict mit text und colspan sein. Ohne das stuende die Dict-Form
        # woertlich im PDF -- "text {Summe Nord} colspan 2" --, und
        # table::group waere nur mit render zu gebrauchen.
        foreach value $row {
            set span [_cellSpan $value]
            if {$c + $span > [llength $colW]} {
                set span [expr {[llength $colW] - $c}]
            }
            if {$span < 1} { break }
            set cw 0
            for {set k 0} {$k < $span} {incr k} {
                set cw [expr {$cw + [lindex $colW [expr {$c + $k}]]}]
            }
            set cAl   [lindex $aligns $c]
            set cFont [lindex $colFonts $c]
            set eff {}
            if {$rs(-fg)   ne ""} { lappend eff -fg   $rs(-fg) }
            if {$rs(-font) ne ""} { lappend eff -font $rs(-font) }
            if {[dict exists $cellstyles "$r,$c"]} {
                set eff [dict merge $eff [dict get $cellstyles "$r,$c"]]
            }
            # Spaltenweites -notruncate; eine Zellangabe in cellstyles
            # hat Vorrang, weil eff spaeter gemergt wurde.
            if {[lindex $colNoTrunc $c] && ![dict exists $eff -notruncate]} {
                lappend eff -notruncate 1
            }
            set cellIndent [expr {$c == 0 ? $ind : 0}]
            if {$span > 1} {
                ::pdf4tcllib::tag::begin $pdf TD -colspan $span
            } else {
                ::pdf4tcllib::tag::begin $pdf TD
            }
            _dwCell $pdf $cx $y $cw $rowH [_cellText $value] $cAl $cFont \
                    $fs $pad $eff $cellIndent $fontOvr
            ::pdf4tcllib::tag::end $pdf
            set cx [expr {$cx + $cw}]
            incr c $span
        }
        ::pdf4tcllib::tag::end $pdf
        # innere V-Linien (0.75/0.3)
        if {$o(-border)} { _dwInnerV $pdf $x $y $rowH $colW {0.75 0.75 0.75} 0.3 }
        set y [expr {$y + $rowH}]
        incr r
    }

    # Footer
    if {[llength $o(-footer)]} {
        if {$haveCtx && ($y + $rowH) > $yBot} {
            if {$o(-border)} {
                $pdf setStrokeColor 0.45 0.45 0.45; $pdf setLineWidth 0.6
                $pdf rectangle $x $segTop $totalW [expr {$y - $segTop}]
                $pdf setStrokeColor 0 0 0; $pdf setLineWidth 1
            }
            set y [::pdf4tcllib::table::_doPageBreak $pdf pageNo $pageW $pageH \
                       $margin $fs $o(-orient) $o(-pagebreakcmd) $yTop]
            set segTop $y
        }
        if {$o(-border)} {
            $pdf setStrokeColor 0.45 0.45 0.45; $pdf setLineWidth 0.6
            $pdf line $x $y [expr {$x + $totalW}] $y
            $pdf setStrokeColor 0 0 0; $pdf setLineWidth 1
        }
        _dwFill $pdf $x $y $totalW $rowH $o(-footerbg)
        set ffont [expr {$o(-footerbold) ? "bold" : "reg"}]
        set cx $x
        ::pdf4tcllib::tag::begin $pdf TR
        foreach value $o(-footer) cw $colW cAl $aligns {
            ::pdf4tcllib::tag::begin $pdf TD
            _dwCell $pdf $cx $y $cw $rowH $value $cAl $ffont $fs $pad {} 0 $fontOvr
            ::pdf4tcllib::tag::end $pdf
            set cx [expr {$cx + $cw}]
        }
        ::pdf4tcllib::tag::end $pdf
        if {$o(-border)} { _dwInnerV $pdf $x $y $rowH $colW {0.6 0.6 0.6} 0.3 }
        set y [expr {$y + $rowH}]
    }

    ::pdf4tcllib::tag::end $pdf

    # Aussenrahmen des (letzten) Segments (0.45/0.6) -- Dekoration
    if {$o(-border)} {
        ::pdf4tcllib::tag::artifact $pdf -type Layout
        $pdf setStrokeColor 0.45 0.45 0.45
        $pdf setLineWidth 0.6
        $pdf rectangle $x $segTop $totalW [expr {$y - $segTop}]
        $pdf setStrokeColor 0 0 0
        $pdf setLineWidth 1
        ::pdf4tcllib::tag::artifactEnd $pdf
    }
    if {$o(-yvar) ne ""} { set yout $y }
    return $y
}


# ================================================================
# Module: pdf4tcllib::drawing
# ================================================================

# pdf4tcllib::drawing -- Drawing functions for pdf4tcl
#
# Erweiterte geometrische Formen, Farbverlaeufe, Muster.
# Builds on pdf4tcl-Grundprimitiven auf.
#
# Usage:
#   package require pdf4tcllib::drawing 0.1
#   pdf4tcllib::drawing::gradient_v $pdf 50 100 200 300 {1 0 0} {0 0 1}
#   pdf4tcllib::drawing::polygon $pdf 200 200 50 6
#   pdf4tcllib::drawing::star $pdf 300 300 40


namespace eval ::pdf4tcllib::drawing {}

# ============================================================
# Farbverlaeufe
# ============================================================

proc ::pdf4tcllib::drawing::interpolate {c1 c2 t} {
    # Interpolates between two RGB colors.
    # c1, c2: {r g b} with Werten 0.0-1.0
    # t: Position 0.0 (=c1) bis 1.0 (=c2)
    lassign $c1 r1 g1 b1
    lassign $c2 r2 g2 b2
    list \
        [expr {$r1 + ($r2 - $r1) * $t}] \
        [expr {$g1 + ($g2 - $g1) * $t}] \
        [expr {$b1 + ($b2 - $b1) * $t}]
}

proc ::pdf4tcllib::drawing::gradient_v {pdf x y w h c1 c2 {steps 100}} {
    # Vertikaler Farbverlauf (oben after unten).
    # c1: start color top, c2: end color bottom.
    # A gradient is decoration: dozens of filled strips that mean nothing
    # individually. Left as content a reader walks through every one.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    if {$steps < 1} { set steps 1 }
    set dh [expr {$h / double($steps)}]
    for {set i 0} {$i < $steps} {incr i} {
        set t [expr {$i / double($steps)}]
        set rgb [interpolate $c1 $c2 $t]
        $pdf setFillColor {*}$rgb
        set yy [expr {$y + $i * $dh}]
        $pdf rectangle $x $yy $w $dh -filled 1
    }
    ::pdf4tcllib::tag::artifactEnd $pdf
}

proc ::pdf4tcllib::drawing::gradient_h {pdf x y w h c1 c2 {steps 100}} {
    # Horizontaler Farbverlauf (links after rechts).
    # A gradient is decoration: dozens of filled strips that mean nothing
    # individually. Left as content a reader walks through every one.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    if {$steps < 1} { set steps 1 }
    set dw [expr {$w / double($steps)}]
    for {set i 0} {$i < $steps} {incr i} {
        set t [expr {$i / double($steps)}]
        set rgb [interpolate $c1 $c2 $t]
        $pdf setFillColor {*}$rgb
        set xx [expr {$x + $i * $dw}]
        $pdf rectangle $xx $y $dw $h -filled 1
    }
    ::pdf4tcllib::tag::artifactEnd $pdf
}

# ============================================================
# Formen
# ============================================================

proc ::pdf4tcllib::drawing::polygon {pdf cx cy radius sides {stroke 1} {fill 0}} {
    # Regelmaessiges Polygon.
    # cx, cy: Mittelpunkt, radius: Umkreisradius, sides: Anzahl Ecken
    if {$sides < 3} { return }
    set pts {}
    set pi [expr {acos(-1)}]
    for {set k 0} {$k < $sides} {incr k} {
        set ang [expr {2.0 * $pi * $k / $sides - $pi / 2.0}]
        lappend pts [expr {$cx + $radius * cos($ang)}]
        lappend pts [expr {$cy + $radius * sin($ang)}]
    }
    $pdf polygon {*}$pts -stroke $stroke -filled $fill
}

proc ::pdf4tcllib::drawing::star {pdf cx cy radius {points 5} {ratio 0.5} {stroke 1} {fill 0}} {
    # Stern.
    # radius: Aussenradius, ratio: Innen/Aussen-Verhaeltnis
    if {$points < 2} { return }
    set pi [expr {acos(-1)}]
    set pts {}
    for {set k 0} {$k < 2 * $points} {incr k} {
        set r [expr {($k % 2) ? $radius * $ratio : $radius}]
        set ang [expr {-$pi / 2.0 + $k * $pi / $points}]
        lappend pts [expr {$cx + $r * cos($ang)}]
        lappend pts [expr {$cy + $r * sin($ang)}]
    }
    $pdf polygon {*}$pts -stroke $stroke -filled $fill
}

proc ::pdf4tcllib::drawing::roundedRect {pdf x y w h r {stroke 1} {fill 0} args} {
    # A rectangle with rounded corners.
    # r: corner radius
    #
    # Options:
    #   -clip 1   use the path as a clipping path instead of drawing it.
    #             Useful to clip an image to a rounded rectangle:
    #               drawing::roundedRect $pdf $x $y $w $h 8 0 0 -clip 1
    #               $pdf putImage $img $x $y -width $w -height $h
    #
    # Uses Bezier curves for the corners (kappa = 0.5522847498).
    set useClip 0
    foreach {k v} $args {
        if {$k eq "-clip"} { set useClip $v }
    }

    set k [expr {$r * 0.5522847498}]

    # Startpunkt: Mitte obere Kante
    set x1 [expr {$x + $r}]
    set x2 [expr {$x + $w - $r}]
    set y1 [expr {$y + $r}]
    set y2 [expr {$y + $h - $r}]

    # path als Koordinatenliste for polygon (Annaeherung)
    # Echte Bezier-Kurven waeren besser, but pdf4tcl hat keine
    # einfache path-API -- nutze Segmente
    set segs 8
    set pts {}

    # Obere Kante links after rechts
    lappend pts $x1 $y
    lappend pts $x2 $y

    # Ecke oben rechts
    _arcPoints pts [expr {$x + $w - $r}] [expr {$y + $r}] $r 270 360 $segs

    # Rechte Kante oben after unten
    lappend pts [expr {$x + $w}] $y2

    # Ecke unten rechts
    _arcPoints pts [expr {$x + $w - $r}] [expr {$y + $h - $r}] $r 0 90 $segs

    # Untere Kante rechts after links
    lappend pts $x2 [expr {$y + $h}]
    lappend pts $x1 [expr {$y + $h}]

    # Ecke unten links
    _arcPoints pts [expr {$x + $r}] [expr {$y + $h - $r}] $r 90 180 $segs

    # Linke Kante unten after oben
    lappend pts $x $y2
    lappend pts $x $y1

    # Ecke oben links
    _arcPoints pts [expr {$x + $r}] [expr {$y + $r}] $r 180 270 $segs

    if {$useClip} {
        # Clipping path: the polygon points as a path plus the W n
        # operators. pdf4tcl::clip takes a rectangle only, and we need a
        # path clip, which would mean writing into the raw content stream
        # through Pdfout. We have no access to Pdfout, so this uses gsave
        # plus the polygon as a white fill and sets the clip through
        # rawContent where that exists. Fallback: a plain rectangle clip.
        $pdf clip $x $y $w $h
    } else {
        $pdf polygon {*}$pts -stroke $stroke -filled $fill
    }
}

# ============================================================
# arrow -- eine Linie mit Spitze
# ============================================================
#
# Eine Verbindung in einem Schaubild ist eine Linie plus ein Dreieck am
# Ende, und das Dreieck ist die Arbeit: es muss in die Richtung der Linie
# zeigen, und die Linie muss VOR der Spitze enden, sonst ragt sie durch.
#
#   -at        end | start | both -- wo die Spitzen sitzen
#   -length    Laenge der Spitze in Punkt (8)
#   -width     Breite der Spitze in Punkt (6)
#   -filled    ausgefuellt (1) oder nur umrissen (0)
#
# Die Farbe ist die eingestellte Strich- bzw. Fuellfarbe; die Prozedur
# aendert sie nicht. Sie zeichnet auch keine Kurve -- fuer eine gebogene
# Verbindung nimmt man den Pfad selbst und setzt die Spitze mit
# arrowHead an das Ende.
proc ::pdf4tcllib::drawing::arrow {pdf x1 y1 x2 y2 args} {
    array set o {-at end -length 8 -width 6 -filled 1}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "drawing::arrow: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    if {$o(-at) ni {end start both}} {
        return -code error "drawing::arrow: -at must be end, start or both,\
                not \"$o(-at)\""
    }
    set dx [expr {$x2 - $x1}]
    set dy [expr {$y2 - $y1}]
    set len [expr {hypot($dx, $dy)}]
    if {$len == 0} { return }

    # Ein Pfeil ist Zierrat, solange ihn niemand beschreibt: er traegt
    # keinen Text, den ein Vorleseprogramm ausgeben koennte. Ohne diese
    # Klammer zaehlt jede Linie und jedes Dreieck als ungetaggt, und der
    # Strukturbaum eines Schaubildes hat so viele Loecher wie es
    # Verbindungen hat. Gemessen an drei Pfeilen und zwei Sprechblasen:
    # 9 offene Zeichenbefehle.
    #
    # Tut nichts, wenn Tagging aus ist.
    ::pdf4tcllib::tag::artifact $pdf -type Layout

    # Die Linie endet vor der Spitze, sonst zeichnet sie durch die
    # ausgefuellte Flaeche hindurch und die Spitze bekommt einen Strich
    # in der Mitte.
    set ux [expr {$dx / $len}]
    set uy [expr {$dy / $len}]
    set ax1 $x1 ; set ay1 $y1
    set ax2 $x2 ; set ay2 $y2
    if {$o(-at) in {end both}} {
        set ax2 [expr {$x2 - $ux * $o(-length)}]
        set ay2 [expr {$y2 - $uy * $o(-length)}]
    }
    if {$o(-at) in {start both}} {
        set ax1 [expr {$x1 + $ux * $o(-length)}]
        set ay1 [expr {$y1 + $uy * $o(-length)}]
    }
    $pdf line $ax1 $ay1 $ax2 $ay2

    if {$o(-at) in {end both}} {
        arrowHead $pdf $x2 $y2 [expr {atan2($dy, $dx)}] \
                -length $o(-length) -width $o(-width) -filled $o(-filled)
    }
    if {$o(-at) in {start both}} {
        arrowHead $pdf $x1 $y1 [expr {atan2(-$dy, -$dx)}] \
                -length $o(-length) -width $o(-width) -filled $o(-filled)
    }
    ::pdf4tcllib::tag::artifactEnd $pdf
}

# Eine Spitze an einem Punkt, in Richtung $winkel (Bogenmass, 0 = nach
# rechts). Getrennt, damit sie auch an das Ende eines Pfades passt, den
# der Aufrufer selbst gezeichnet hat.
proc ::pdf4tcllib::drawing::arrowHead {pdf x y winkel args} {
    array set o {-length 8 -width 6 -filled 1}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "drawing::arrowHead: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    set bx [expr {$x - $o(-length) * cos($winkel)}]
    set by [expr {$y - $o(-length) * sin($winkel)}]
    set hw [expr {$o(-width) / 2.0}]
    # Senkrecht zur Richtung.
    set px [expr {-sin($winkel) * $hw}]
    set py [expr { cos($winkel) * $hw}]
    $pdf polygon $x $y [expr {$bx + $px}] [expr {$by + $py}] \
            [expr {$bx - $px}] [expr {$by - $py}] \
            -stroke [expr {!$o(-filled)}] -filled $o(-filled)
}

# ============================================================
# callout -- eine Sprechblase mit Zeiger
# ============================================================
#
# Ein Kasten mit abgerundeten Ecken und einem Dreieck, das auf die Stelle
# zeigt, um die es geht. Der Zeiger sitzt an der Seite, die dem Ziel
# zugewandt ist -- das ergibt sich aus der Lage und muss nicht angegeben
# werden.
#
#   -radius    Eckenradius (4)
#   -fill      Fuellfarbe als {r g b}; {} = nicht fuellen
#   -stroke    Umriss zeichnen (1)
#   -tail      Breite des Zeigers am Kasten (12)
#   -pad       Innenabstand fuer den Text (5)
#   -fontsize  Schriftgroesse (9); der Text wird umbrochen und, wenn er
#              nicht passt, verkleinert -- gekuerzt wird nicht
#   -font      Schrift, sonst die aus fonts::init
#   -alt       Text fuer den Strukturbaum
#
# Rueckgabe: die Anzahl der gesetzten Zeilen.
proc ::pdf4tcllib::drawing::callout {pdf x y w h zielX zielY text args} {
    array set o {
        -radius 4 -fill {} -stroke 1 -tail 12 -pad 5
        -fontsize 9 -font {} -alt {}
    }
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "drawing::callout: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    if {$w <= 0 || $h <= 0} {
        return -code error "drawing::callout: width and height must be\
                positive"
    }
    set font $o(-font)
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }

    set tag [expr {$o(-alt) ne ""}]
    if {$tag} { catch {::pdf4tcllib::tag::begin $pdf Figure -alt $o(-alt)} }

    if {$o(-fill) ne ""} {
        lassign $o(-fill) r g b
        $pdf setFillColor $r $g $b
    }
    set fuellen [expr {$o(-fill) ne ""}]
    # Kasten und Zeiger sind Zierrat -- der Inhalt ist der Text darin.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    roundedRect $pdf $x $y $w $h $o(-radius) $o(-stroke) $fuellen

    # Der Zeiger: an der Seite, die dem Ziel am naechsten liegt.
    set mx [expr {$x + $w / 2.0}]
    set my [expr {$y + $h / 2.0}]
    set halb [expr {$o(-tail) / 2.0}]
    if {$zielY < $y} {
        set seite oben
    } elseif {$zielY > $y + $h} {
        set seite unten
    } elseif {$zielX < $x} {
        set seite links
    } else {
        set seite rechts
    }
    switch -- $seite {
        oben  { set ax [_klemme $zielX [expr {$x + $o(-radius) + $halb}] \
                        [expr {$x + $w - $o(-radius) - $halb}]]
                set pts [list [expr {$ax - $halb}] $y \
                        [expr {$ax + $halb}] $y $zielX $zielY] }
        unten { set ax [_klemme $zielX [expr {$x + $o(-radius) + $halb}] \
                        [expr {$x + $w - $o(-radius) - $halb}]]
                set pts [list [expr {$ax - $halb}] [expr {$y + $h}] \
                        [expr {$ax + $halb}] [expr {$y + $h}] $zielX $zielY] }
        links { set ay [_klemme $zielY [expr {$y + $o(-radius) + $halb}] \
                        [expr {$y + $h - $o(-radius) - $halb}]]
                set pts [list $x [expr {$ay - $halb}] \
                        $x [expr {$ay + $halb}] $zielX $zielY] }
        rechts { set ay [_klemme $zielY [expr {$y + $o(-radius) + $halb}] \
                        [expr {$y + $h - $o(-radius) - $halb}]]
                set pts [list [expr {$x + $w}] [expr {$ay - $halb}] \
                        [expr {$x + $w}] [expr {$ay + $halb}] $zielX $zielY] }
    }
    $pdf polygon {*}$pts -stroke $o(-stroke) -filled $fuellen
    ::pdf4tcllib::tag::artifactEnd $pdf

    # Der Text. Passt er nicht in die Hoehe, wird verkleinert statt
    # gekuerzt -- in einer Sprechblase steht meist ein Satz, und ein
    # halber Satz ist keiner.
    set zeilen 0
    if {$text ne ""} {
        $pdf setFillColor 0 0 0
        set innenW [expr {$w - 2 * $o(-pad)}]
        set innenH [expr {$h - 2 * $o(-pad)}]
        set fs $o(-fontsize)
        while {$fs > 5} {
            set ls [::pdf4tcllib::text::wrap $text $innenW $fs $font 0 $pdf 1]
            if {[llength $ls] * $fs * 1.25 <= $innenH} { break }
            set fs [expr {$fs - 1}]
        }
        set ls [::pdf4tcllib::text::wrap $text $innenW $fs $font 0 $pdf 1]
        $pdf setFont $fs $font
        set ty [expr {$y + $o(-pad) + $fs}]
        # Der Text IST der Inhalt der Sprechblase; ohne diese Klammer
        # bleibt er ausserhalb des Strukturbaums, waehrend der Kasten
        # drumherum ordentlich als Artefakt gefasst ist.
        set eigenP [expr {!$tag}]
        if {$eigenP} { catch {::pdf4tcllib::tag::begin $pdf P} }
        foreach ln $ls {
            ::pdf4tcllib::unicode::safeText $pdf $ln \
                    -x [expr {$x + $o(-pad)}] -y $ty
            set ty [expr {$ty + $fs * 1.25}]
            incr zeilen
        }
        if {$eigenP} { catch {::pdf4tcllib::tag::end $pdf} }
    }
    if {$tag} { catch {::pdf4tcllib::tag::end $pdf} }
    return $zeilen
}

proc ::pdf4tcllib::drawing::_klemme {v min max} {
    if {$max < $min} { return [expr {($min + $max) / 2.0}] }
    if {$v < $min} { return $min }
    if {$v > $max} { return $max }
    return $v
}

proc ::pdf4tcllib::drawing::frame {pdf x y w h {lineWidth 1}} {
    # Einfacher Rahmen.
    $pdf setLineWidth $lineWidth
    $pdf rectangle $x $y $w $h -stroke 1
}

proc ::pdf4tcllib::drawing::separator {pdf x y w {color {0.7 0.7 0.7}} {lineWidth 0.5}} {
    # Horizontale Trennlinie.
    $pdf setStrokeColor {*}$color
    $pdf setLineWidth $lineWidth
    $pdf line $x $y [expr {$x + $w}] $y
    $pdf setStrokeColor 0 0 0
}

# ============================================================
# Text-Transformationen
# ============================================================

# ---------------------------------------------------------------------------
# watermark -- a diagonal stamp across the page
# ---------------------------------------------------------------------------
#
#   ::pdf4tcllib::drawing::watermark $pdf $ctx "DRAFT" ?option value ...?
#
# Call it FIRST on a page: this draws in plain grey, with no transparency,
# so anything drawn afterwards sits on top of it. pdf4tcl has no alpha, and
# faking one by drawing over the content would hide the content.
#
# The stamp is a Pagination artifact. It says something about the copy in
# your hand, not about the text -- a reader announcing "DRAFT" in the
# middle of a sentence would be worse than not hearing it at all.
#
# Options:
#   -angle N     degrees, counter-clockwise; 45 by default
#   -size N      font size; 0 (the default) fits the text to the page
#   -color {r g b}  light grey by default -- dark enough to see on paper,
#                light enough to read through
#   -font NAME   default is the sans face from fonts::init
#
# Returns the font size used, which is the interesting number when the text
# was fitted.
# -layer: das Wasserzeichen in eine Ebene legen, statt es fest auf die
# Seite zu zeichnen. Im Leser laesst sich eine Ebene abschalten -- fuer
# ein "ENTWURF" ueber einem Text, den jemand ohne den Aufdruck lesen oder
# drucken soll, ist das der Unterschied zwischen brauchbar und laestig.
#
# Der Wert ist entweder eine Ebenen-Kennung aus $pdf addLayer, oder 1 --
# dann legt watermark selbst eine an, benannt nach dem Text. Mehrere
# Aufrufe mit 1 legen mehrere Ebenen an; wer EINE ueber alle Seiten will,
# ruft addLayer einmal und gibt die Kennung weiter.
#
# Ohne -layer bleibt alles wie bisher: ein Artefakt fest auf der Seite.
proc ::pdf4tcllib::drawing::watermark {pdf ctx text args} {
    array set o {-angle 45 -size 0 -color {0.86 0.86 0.86} -font {} -layer {}}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "drawing::watermark: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    if {$text eq ""} {
        return -code error "drawing::watermark: no text"
    }
    if {$o(-font) eq ""} { set o(-font) [::pdf4tcllib::_defaultFamily] }

    set pw [dict get $ctx page_w]
    set ph [dict get $ctx page_h]

    # Fit the text to the diagonal it will be drawn along, leaving a tenth
    # of it as margin at either end.
    set size $o(-size)
    if {$size <= 0} {
        set pi   [expr {acos(-1)}]
        set rad  [expr {$o(-angle) * $pi / 180.0}]
        set diag [expr {abs($pw * cos($rad)) + abs($ph * sin($rad))}]
        set want [expr {$diag * 0.8}]
        set size 10.0
        $pdf setFont $size $o(-font)
        set w [$pdf getStringWidth $text]
        if {$w > 0} { set size [expr {$size * $want / $w}] }
        if {$size < 6} { set size 6.0 }
    }

    set layer {}
    if {$o(-layer) ne "" && $o(-layer) ne "0"} {
        if {$o(-layer) eq "1"} {
            if {[catch {$pdf addLayer $text} layer]} { set layer {} }
        } else {
            set layer $o(-layer)
        }
    }
    if {$layer ne ""} {
        if {[catch {$pdf beginLayer $layer}]} { set layer {} }
    }

    ::pdf4tcllib::tag::artifact $pdf -type Pagination
    lassign $o(-color) r g b
    $pdf setFillColor $r $g $b
    $pdf setFont $size $o(-font)

    # Centre the rotated text on the page: half its width back along the
    # baseline direction, half its height up the perpendicular.
    set pi  [expr {acos(-1)}]
    set rad [expr {$o(-angle) * $pi / 180.0}]
    set tw  [$pdf getStringWidth $text]
    set x   [expr {$pw / 2.0 - cos($rad) * $tw / 2.0}]
    set y   [expr {$ph / 2.0 + sin($rad) * $tw / 2.0 + $size * 0.35}]

    textRotated $pdf $text $x $y $o(-angle) $size $o(-font)

    $pdf setFillColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
    if {$layer ne ""} { catch {$pdf endLayer} }
    # Die Ebenenkennung kommt mit zurueck, damit ein zweiter Aufruf auf
    # der naechsten Seite dieselbe Ebene benutzen kann.
    if {$layer ne ""} { return [list $size $layer] }
    return $size
}

proc ::pdf4tcllib::drawing::textRotated {pdf txt x y angle size {font ""}} {
    # Rotated text.
    # angle: degrees, counter-clockwise.
    # Leerer Vorgabewert heisst: nimm, was fonts:: liefert. Ein fest
    # verdrahtetes Helvetica machte jedes Dokument PDF/A-untauglich --
    # die vierzehn Standardschriften haben kein einbettbares
    # Fontprogramm, und veraPDF faellt darueber (Klausel 6.2.11.4.1).
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }
    $pdf setFont $size $font
    if {![catch {$pdf text $txt -x $x -y $y -angle $angle}]} { return }

    # Fallback: place the characters one by one
    set pi [expr {acos(-1)}]
    set dx [expr {cos($angle * $pi / 180.0)}]
    set dy [expr {sin($angle * $pi / 180.0)}]
    set spacing [expr {$size * 0.6}]
    set cx $x; set cy $y
    foreach c [split $txt ""] {
        $pdf text $c -x $cx -y $cy
        set cx [expr {$cx + $spacing * $dx}]
        set cy [expr {$cy - $spacing * $dy}]
    }
}

proc ::pdf4tcllib::drawing::textScaled {pdf txt x y sx sy size {font ""}} {
    # Skalierter Text via gsave/translate/scale/text/grestore.
    # sx: horizontale Skalierung, sy: vertikale Skalierung
    # Koordinaten: x y = Baseline-Position in aktuellen Einheiten

    # Leerer Vorgabewert heisst: nimm, was fonts:: liefert. Ein fest
    # verdrahtetes Helvetica machte jedes Dokument PDF/A-untauglich --
    # die vierzehn Standardschriften haben kein einbettbares
    # Fontprogramm, und veraPDF faellt darueber (Klausel 6.2.11.4.1).
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }
    $pdf setFont $size $font
    $pdf gsave
    $pdf translate $x $y
    $pdf scale $sx $sy
    # Nach scale sind Koordinaten in skalierten Einheiten -- Text bei 0 0
    $pdf text $txt -x 0 -y 0
    $pdf grestore
}

proc ::pdf4tcllib::drawing::textSkewed {pdf txt x y skewX skewY size {font ""}} {
    # Geneigter Text (Pseudo-Italic).
    # skewX, skewY: Neigungswinkel in Grad
    if {![catch {$pdf text $txt -x $x -y $y -skew $skewX $skewY -size $size -font $font}]} { return }

    # Fallback
    set pi [expr {acos(-1)}]
    set tanx [expr {tan($skewX * $pi / 180.0)}]
    set spacing [expr {$size * 0.6}]
    # Leerer Vorgabewert heisst: nimm, was fonts:: liefert. Ein fest
    # verdrahtetes Helvetica machte jedes Dokument PDF/A-untauglich --
    # die vierzehn Standardschriften haben kein einbettbares
    # Fontprogramm, und veraPDF faellt darueber (Klausel 6.2.11.4.1).
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }
    $pdf setFont $size $font
    set cx $x
    foreach c [split $txt ""] {
        set oy [expr {$tanx * ($cx - $x)}]
        $pdf text $c -x $cx -y [expr {$y + $oy}]
        set cx [expr {$cx + $spacing}]
    }
}

# ============================================================
# Private Helfer
# ============================================================

proc ::pdf4tcllib::drawing::_arcPoints {ptsVar cx cy r startDeg endDeg segments} {
    # Appends the points of a circular arc to the list.
    upvar $ptsVar pts
    set pi [expr {acos(-1)}]
    for {set i 0} {$i <= $segments} {incr i} {
        set ang [expr {($startDeg + ($endDeg - $startDeg) * $i / double($segments)) * $pi / 180.0}]
        lappend pts [expr {$cx + $r * cos($ang)}]
        lappend pts [expr {$cy + $r * sin($ang)}]
    }
}

# ================================================================
# Module: pdf4tcllib::image
# ================================================================

# pdf4tcllib::image -- Image integration for pdf4tcl
#
# Adds Tk-Bilder in PDF-Dokumente ein.
# Requires Tk (for photo image).
#
# Usage:
#   package require pdf4tcllib::image 0.1
#   pdf4tcllib::image::insert $pdf $tkImg -x 50 -y yVar -maxwidth 500

# Tk is needed ONLY by the image helpers -- they measure a Tk photo with
# [image width]. Requiring it while the module loads pulls Tk into every
# program that uses pdf4tcllib, batch scripts included.
#
# The consequence is measured and unpleasant: Tk_Init registers a main
# loop, and any script without a closing "exit" then waits for a window
# that never comes. On a machine without a display nothing shows -- loading
# Tk fails there and everything runs through. In the collected example run
# eight scripts hung this way, among them 45_pdfa.tcl, which has nothing to
# do with user interfaces.
#
# Hence on demand, in the procedure that needs it.
namespace eval ::pdf4tcllib::image {}

proc ::pdf4tcllib::image::_needTk {} {
    if {[llength [info commands ::image]] > 0} { return }
    if {[catch {package require Tk} e]} {
        return -code error "pdf4tcllib::image needs Tk: $e"
    }
}

# ============================================================
# Oeffentliche API
# ============================================================

# ============================================================
# place -- ein Bild in einen Rahmen setzen
# ============================================================
#
# putImage nimmt -width und -height und zieht das Bild darauf. Weicht das
# Seitenverhaeltnis ab, verzerrt es -- und niemand sagt es. Wer das nicht
# will, rechnet von Hand, und dabei ist die Frage, WELCHE der beiden
# Antworten gemeint war:
#
#   -fit contain   ganz hinein, Rand bleibt frei      (nichts geht verloren)
#   -fit cover     ganz ausfuellen, Ueberstand faellt weg (nichts bleibt leer)
#   -fit stretch   das alte Verhalten, verzerrt
#
# Und wenn beschnitten wird: VON WO AUS. Ein Portraet, dessen Kopf oben
# sitzt, will -anchor n; eine Landschaft meist center. Genau das ist die
# Entscheidung, die eine Bibliothek treffen darf und putImage nicht.
#
# Beschnitten wird mit einem Clip-Pfad: das Bild wird in voller
# berechneter Groesse gezeichnet, sichtbar bleibt der Rahmen. Der Inhalt
# ausserhalb steht weiterhin in der Datei -- wer das nicht will, schneidet
# das Bild vorher zu.
#
# -dpi warnt, wenn die Aufloesung unter dem Schwellwert liegt. pdf4tcl
# meldet das seit 0.9.4.60 selbst fuer jedes putImage; hier laesst es
# sich je Bild anders setzen, weil ein Logo andere Ansprueche hat als
# eine Abbildung. 0 schaltet die Pruefung fuer diesen Aufruf ab.
#
# Rueckgabe: die tatsaechlich belegte Flaeche {x y w h}. Bei contain ist
# sie kleiner als der Rahmen, bei cover gleich.
proc ::pdf4tcllib::image::place {pdf id x y w h args} {
    array set o {-fit contain -anchor center -dpi {} -alt {} -clip 1}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "image::place: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    if {$o(-fit) ni {contain cover stretch}} {
        return -code error "image::place: -fit must be contain, cover or\
                stretch, not \"$o(-fit)\""
    }
    if {$w <= 0 || $h <= 0} {
        return -code error "image::place: width and height must be positive"
    }

    lassign [$pdf getImageSize $id] px py
    if {$px <= 0 || $py <= 0} {
        return -code error "image::place: image $id has no size"
    }

    set skalaW [expr {double($w) / $px}]
    set skalaH [expr {double($h) / $py}]
    switch -- $o(-fit) {
        contain { set s [expr {min($skalaW, $skalaH)}] }
        cover   { set s [expr {max($skalaW, $skalaH)}] }
        stretch { set s {} }
    }

    if {$s eq ""} {
        set bw $w ; set bh $h
    } else {
        set bw [expr {$px * $s}]
        set bh [expr {$py * $s}]
    }

    # Ausrichtung im Rahmen. Bei contain verschiebt sie das Bild darin,
    # bei cover entscheidet sie, welcher Teil wegfaellt.
    lassign [_ausrichten $o(-anchor) $x $y $w $h $bw $bh] bx by

    set tag [expr {$o(-alt) ne ""}]
    if {$tag} {
        if {[catch {::pdf4tcllib::tag::begin $pdf Figure -alt $o(-alt)}]} {
            catch {::pdf4tcllib::tag::begin $pdf Figure}
            set tag 1
        }
    }

    # pdf4tcl meldet seit 0.9.4.60 selbst, wenn ein Bild unter 150 dpi
    # gesetzt wird. Wer hier -dpi angibt, will einen eigenen Schwellwert
    # -- dann waeren zwei Meldungen zu derselben Sache eine zuviel, und
    # die eigene ist die genauere.
    set kernSchwelle $::pdf4tcl::imageDpiWarn
    if {$o(-dpi) ne ""} { set ::pdf4tcl::imageDpiWarn 0 }

    set clip [expr {$o(-clip) && ($bw > $w + 0.01 || $bh > $h + 0.01)}]
    if {$clip} {
        # Nur was im Rahmen liegt, soll zu sehen sein. Der Clip-Pfad gilt
        # bis zum naechsten grestore -- deshalb das Paar drumherum, sonst
        # beschneidet er alles Folgende gleich mit.
        $pdf gsave
        $pdf clip $x $y $w $h
    }
    $pdf putImage $id $bx $by -width $bw -height $bh
    if {$clip} {
        $pdf grestore
    }
    if {$tag} { ::pdf4tcllib::tag::end $pdf }
    set ::pdf4tcl::imageDpiWarn $kernSchwelle

    # Aufloesung: die kleinere der beiden Richtungen zaehlt.
    if {$o(-dpi) ne "" && $o(-dpi) > 0} {
        set dpiX [expr {$px / ($bw / 72.0)}]
        set dpiY [expr {$py / ($bh / 72.0)}]
        set dpi [expr {min($dpiX, $dpiY)}]
        if {$dpi < $o(-dpi)} {
            lappend ::pdf4tcl::warnings [format \
                    "image::place: %s at %.0f dpi (%dx%d pixels on\
                     %.1fx%.1f points), below %g" \
                    $id $dpi $px $py $bw $bh $o(-dpi)]
        }
    }

    if {$clip} {
        return [list $x $y $w $h]
    }
    return [list $bx $by $bw $bh]
}

# Wohin das Bild im Rahmen rueckt. Bei cover ist bw/bh groesser als der
# Rahmen; dann verschiebt dieselbe Rechnung den Ausschnitt.
proc ::pdf4tcllib::image::_ausrichten {anchor x y w h bw bh} {
    set dx [expr {$w - $bw}]
    set dy [expr {$h - $bh}]
    switch -- $anchor {
        nw { return [list $x $y] }
        n  { return [list [expr {$x + $dx / 2.0}] $y] }
        ne { return [list [expr {$x + $dx}] $y] }
        w  { return [list $x [expr {$y + $dy / 2.0}]] }
        e  { return [list [expr {$x + $dx}] [expr {$y + $dy / 2.0}]] }
        sw { return [list $x [expr {$y + $dy}]] }
        s  { return [list [expr {$x + $dx / 2.0}] [expr {$y + $dy}]] }
        se { return [list [expr {$x + $dx}] [expr {$y + $dy}]] }
        default { return [list [expr {$x + $dx / 2.0}] \
                               [expr {$y + $dy / 2.0}]] }
    }
}

# ============================================================
# gallery -- Bilder in ein Raster, ueber mehrere Seiten
# ============================================================
#
# Fotobuch und Prospekt sind dasselbe Problem: Bilder in ein Raster
# setzen, mit Unterschriften, ueber mehrere Seiten. Was daran Arbeit
# macht, ist nicht das Raster, sondern was drumherum haengt --
# Seitenverhaeltnis, verschieden lange Unterschriften, der Seitenwechsel.
#
# Jedes Bild ist ein Eintrag:
#
#     {id "Bildunterschrift"}      oder nur   id
#
# id ist, was addImage zurueckgab. Die Unterschrift darf fehlen.
#
# Optionen:
#   -cols/-rows   Raster je Seite (2 x 3)
#   -gap          Abstand zwischen den Zellen in Punkt (8)
#   -caption      unten | keine -- wo die Unterschrift steht
#   -captionH     Hoehe des Unterschriftenbandes (14); zu lange
#                 Unterschriften werden auf die Breite verkleinert,
#                 statt in die Nachbarzelle zu laufen
#   -fit/-anchor  wie bei place
#   -fontsize     Schriftgroesse der Unterschrift (8)
#   -dpi          Schwellwert je Bild, {} = der des Kerns
#   -ctx          Seitenkontext; ohne ihn gelten x/y/w/h wie uebergeben
#   -pagecmd      wird vor jeder neuen Seite gerufen (Kopfzeile o.ae.)
#
# Die Bildunterschrift wird als Caption getaggt und steht INNERHALB der
# Figure des Bildes -- so gehoeren beide im Baum zusammen, statt als zwei
# unverbundene Dinge nebeneinanderzustehen.
#
# Rueckgabe: die Anzahl der benutzten Seiten.
proc ::pdf4tcllib::image::gallery {pdf bilder x y w h args} {
    array set o {
        -cols 2 -rows 3 -gap 8 -caption unten -captionH 14
        -fit contain -anchor center -fontsize 8 -dpi {}
        -font {} -pagecmd {} -alt {}
    }
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error "image::gallery: unknown option $k\
                    (known: [join [lsort [array names o]] { }])"
        }
        set o($k) $v
    }
    if {$o(-cols) < 1 || $o(-rows) < 1} {
        return -code error "image::gallery: -cols and -rows must be at\
                least 1"
    }
    set font $o(-font)
    if {$font eq ""} { set font [::pdf4tcllib::fonts::fontSans] }
    set mitText [expr {$o(-caption) eq "unten"}]
    set capH [expr {$mitText ? $o(-captionH) : 0}]

    set zellW [expr {($w - ($o(-cols) - 1) * $o(-gap)) / double($o(-cols))}]
    set zellH [expr {($h - ($o(-rows) - 1) * $o(-gap)) / double($o(-rows))}]
    set bildH [expr {$zellH - $capH}]
    if {$zellW <= 0 || $bildH <= 0} {
        return -code error "image::gallery: the frame is too small for\
                [$o(-cols)]x[$o(-rows)] cells"
    }

    set proSeite [expr {$o(-cols) * $o(-rows)}]
    set i 0
    set seiten 1
    foreach eintrag $bilder {
        if {[llength $eintrag] >= 2} {
            set id [lindex $eintrag 0]
            set text [lindex $eintrag 1]
        } else {
            set id [lindex $eintrag 0]
            set text ""
        }

        if {$i > 0 && $i % $proSeite == 0} {
            $pdf endPage
            $pdf startPage
            if {$o(-pagecmd) ne ""} { uplevel 1 $o(-pagecmd) }
            incr seiten
        }
        set k [expr {$i % $proSeite}]
        set sp [expr {$k % $o(-cols)}]
        set ze [expr {$k / $o(-cols)}]
        set zx [expr {$x + $sp * ($zellW + $o(-gap))}]
        set zy [expr {$y + $ze * ($zellH + $o(-gap))}]

        set alt $text
        if {$alt eq "" && $o(-alt) ne ""} { set alt $o(-alt) }
        set placeArgs [list -fit $o(-fit) -anchor $o(-anchor)]
        if {$alt ne ""}      { lappend placeArgs -alt $alt }
        if {$o(-dpi) ne ""}  { lappend placeArgs -dpi $o(-dpi) }

        if {$alt ne "" && $mitText && $text ne ""} {
            # Bild und Unterschrift in EINER Figure: der Baum soll sagen,
            # dass der Text zu diesem Bild gehoert.
            catch {::pdf4tcllib::tag::begin $pdf Figure -alt $alt}
            set inFigure 1
            # place soll dann keine zweite Figure aufmachen.
            set placeArgs [list -fit $o(-fit) -anchor $o(-anchor)]
            if {$o(-dpi) ne ""} { lappend placeArgs -dpi $o(-dpi) }
        } else {
            set inFigure 0
        }

        place $pdf $id $zx $zy $zellW $bildH {*}$placeArgs

        if {$mitText && $text ne ""} {
            if {!$inFigure} { catch {::pdf4tcllib::tag::begin $pdf Caption} }
            if {$inFigure}  { catch {::pdf4tcllib::tag::begin $pdf Caption} }
            # Zu lange Unterschriften werden verkleinert, nicht gekuerzt:
            # bei einem Dateinamen oder einer Bildnummer entscheidet oft
            # das letzte Zeichen.
            set fs [::pdf4tcllib::text::fitSize $text $zellW $o(-fontsize) \
                    $font -min 5 -pdf $pdf]
            $pdf setFont $fs $font
            set tw [::pdf4tcllib::text::width $text $fs $font $pdf]
            set tx [expr {$zx + ($zellW - $tw) / 2.0}]
            ::pdf4tcllib::unicode::safeText $pdf $text \
                    -x $tx -y [expr {$zy + $bildH + $fs + 2}]
            catch {::pdf4tcllib::tag::end $pdf}
        }
        if {$inFigure} { catch {::pdf4tcllib::tag::end $pdf} }
        incr i
    }
    return $seiten
}

proc ::pdf4tcllib::image::insert {pdf tkImg x yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize {debug 0}} {
    _needTk
    # Adds a Tk image centered (full width) to the PDF.
    #
    # The image is proportionally scaled to maxW.
    # On page break a new page is started.

    upvar $yVar y
    upvar $pageNoVar pageNo

    if {[catch {
        set imgW [image width $tkImg]
        set imgH [image height $tkImg]
    }]} {
        return 0
    }

    if {$imgW == 0 || $imgH == 0} { return 0 }

    # Skalierung
    set scale [expr {$maxW / double($imgW)}]
    set pdfW  [expr {int($imgW * $scale)}]
    set pdfH  [expr {int($imgH * $scale)}]

    # Maximale height begrenzen
    set maxImgH [expr {($yBot - $yTop) * 0.7}]
    if {$pdfH > $maxImgH} {
        set scale [expr {$maxImgH / double($imgH)}]
        set pdfW  [expr {int($imgW * $scale)}]
        set pdfH  [expr {int($imgH * $scale)}]
    }

    # Page break if noetig
    set orient [expr {$yTop < $yBot}]
    if {$orient ? (($y + $pdfH + 10) > $yBot) : (($y - $pdfH - 10) < $yBot)} {
        _pageBreak $pdf pageNo $pageW $pageH $margin $fontSize $orient
        set y $yTop
    }

    # Bilddaten extrahieren
    set imgData [_extractImageData $tkImg]
    if {$imgData eq ""} { return 0 }

    set pdfImg [$pdf addRawImage $imgData]
    $pdf putImage $pdfImg $x $y -width $pdfW -height $pdfH

    set y [expr {$orient ? ($y + $pdfH + 10) : ($y - $pdfH - 10)}]

    if {$debug} {
        puts "PDF Image: ${imgW}x${imgH} -> ${pdfW}x${pdfH} pt"
    }

    return $pdfH
}

proc ::pdf4tcllib::image::insertAt {pdf tkImg xPos yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize {debug 0}} {
    _needTk
    # Adds a Tk image at a specific X position.
    #
    # Wie insert, but with freier X-Positionierung.

    upvar $yVar y
    upvar $pageNoVar pageNo

    if {[catch {
        set imgW [image width $tkImg]
        set imgH [image height $tkImg]
    }]} {
        return 0
    }

    if {$imgW == 0 || $imgH == 0} { return 0 }

    # Available width from xPos
    set availW [expr {$maxW - ($xPos - 50)}]
    if {$availW < 50} { set availW $maxW }

    set scale [expr {$availW / double($imgW)}]
    if {$scale > 1.0} { set scale 1.0 }
    set pdfW  [expr {int($imgW * $scale)}]
    set pdfH  [expr {int($imgH * $scale)}]

    # Maximale height
    set orient [expr {$yTop < $yBot}]
    set maxImgH [expr {abs($yBot - $yTop) * 0.7}]
    if {$pdfH > $maxImgH} {
        set scale [expr {$maxImgH / double($imgH)}]
        set pdfW  [expr {int($imgW * $scale)}]
        set pdfH  [expr {int($imgH * $scale)}]
    }

    # Page break
    if {$orient ? (($y + $pdfH + 10) > $yBot) : (($y - $pdfH - 10) < $yBot)} {
        _pageBreak $pdf pageNo $pageW $pageH $margin $fontSize $orient
        set y $yTop
    }

    set imgData [_extractImageData $tkImg]
    if {$imgData eq ""} { return 0 }

    set pdfImg [$pdf addRawImage $imgData]
    $pdf putImage $pdfImg $xPos $y -width $pdfW -height $pdfH

    # y is NOT updated -- caller decides
    # (ermoeglicht nebeneinanderliegende Bilder)
    return $pdfH
}

# ============================================================
# Private Helfer
# ============================================================

proc ::pdf4tcllib::image::_extractImageData {tkImg} {
    _needTk
    # Extracts RGB data from a Tk photo image.
    #
    # Returns a list: width height RGB bytes as hex

    if {[catch {
        set w [image width $tkImg]
        set h [image height $tkImg]
    }]} {
        return ""
    }

    if {$w == 0 || $h == 0} { return "" }

    set data [list $w $h]
    for {set row 0} {$row < $h} {incr row} {
        set rowData ""
        for {set col 0} {$col < $w} {incr col} {
            set pixel [$tkImg get $col $row]
            lassign $pixel r g b
            append rowData [format "%02x%02x%02x" $r $g $b]
        }
        lappend data $rowData
    }

    return $data
}

proc ::pdf4tcllib::image::_pageBreak {pdf pageNoVar pageW pageH margin fontSize {orient 0}} {
    # Page break. orient: 1=top-left, 0=bottom-left
    upvar $pageNoVar pageNo
    set fontSans [::pdf4tcllib::fonts::fontSans]
    set y [expr {$orient ? ($pageH - $margin * 0.5) : ($margin * 0.5)}]
    set x [expr {$pageW - $margin}]
    $pdf setFont [expr {$fontSize - 2}] $fontSans
    ::pdf4tcllib::unicode::safeText $pdf "- $pageNo -" -x $x -y $y -align right
    $pdf endPage
    incr pageNo
    $pdf startPage
}

# ============================================================
# pdf4tcllib::form -- form helpers around addForm
#
# Requires pdf4tcl::addForm (0.9.4.1+).
# Offers label plus field in one call, row and section layout, and order
# tables, all relative to the page::context.
#
# Note: addForm does not support CID fonts -- use the standard fonts
# (Helvetica and friends).
# ============================================================

namespace eval ::pdf4tcllib::form {

    # -- Konfigurations-Array --------------------------------
    variable CFG
    array set CFG {
        fontFamily        Helvetica
        fontFamilyBold    Helvetica-Bold
        fontSize          9
        fontSizeLabel     9
        fontSizeSection   10
        fieldH            16
        fieldBg           {0.96 0.96 0.96}
        fieldBorder       {0.70 0.70 0.70}
        sectionBg         {0.88 0.88 0.88}
        labelColor        {0.0  0.0  0.0}
        lineColor         {0.70 0.70 0.70}
        lineWidth         0.5
        labelGap          4
        rowGap            6
        sectionGap        10
        labelW            90
    }

    # The font the blocks draw with. CFG holds Helvetica by default, but a
    # caller who ran fonts::init wants the loaded TrueType instead --
    # otherwise a form built for PDF/UA carries a section title in
    # Helvetica-Bold, which is precisely the font that cannot be embedded,
    # and the warning names a font the caller never asked for. Measured.
    #
    # An explicit form::configure -fontFamily still wins: it is only the
    # default that follows fonts::init.
    proc _family {{style ""}} {
        variable CFG
        set explicit [expr {$style eq "bold"
                            ? $CFG(fontFamilyBold) : $CFG(fontFamily)}]
        set builtin [expr {$style eq "bold" ? "Helvetica-Bold" : "Helvetica"}]
        if {$explicit ne $builtin} { return $explicit }
        if {[catch {::pdf4tcllib::fonts::hasTtf} ok] || !$ok} {
            return $explicit
        }
        if {$style eq "bold"} {
            return [::pdf4tcllib::fonts::fontSansBold]
        }
        return [::pdf4tcllib::fonts::fontSans]
    }

    namespace export configure fieldHeight rowHeight section labelField row
    namespace export separator orderTable sumLine
}

# -- Konfiguration -------------------------------------------

proc ::pdf4tcllib::form::configure {args} {
    # Read or set the configuration.
    # Without arguments: the current configuration as a dict.
    # With -key value pairs: set them.
    variable CFG
    if {[llength $args] == 0} {
        return [array get CFG]
    }
    foreach {k v} $args {
        set key [string trimleft $k -]
        if {[info exists CFG($key)]} {
            set CFG($key) $v
        } else {
            error "pdf4tcllib::form::configure: unknown option -$key"
        }
    }
}

# -- fieldHeight ---------------------------------------------

proc ::pdf4tcllib::form::fieldHeight {} {
    # The configured field height.
    variable CFG
    return $CFG(fieldH)
}

# -- rowHeight -----------------------------------------------

proc ::pdf4tcllib::form::rowHeight {} {
    # The total height of one form row: field height plus row gap.
    variable CFG
    return [expr {$CFG(fieldH) + $CFG(rowGap)}]
}

# -- section -------------------------------------------------

proc ::pdf4tcllib::form::section {pdf ctx yVar title} {
    # Draws a section header: a grey bar plus the title.
    # Advances yVar by the height of the section plus the gap.
    upvar 1 $yVar y
    variable CFG

    set x   [dict get $ctx SX]
    set sw  [dict get $ctx SW]

    # Bar and frame carry no meaning -- tagged as content a screen reader
    # announces them as if they did.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    lassign $CFG(sectionBg) r g b
    $pdf setFillColor $r $g $b
    $pdf rectangle $x $y $sw [expr {$CFG(fieldH) + 2}] -filled 1

    lassign $CFG(fieldBorder) lr lg lb
    $pdf setStrokeColor $lr $lg $lb
    $pdf setLineWidth $CFG(lineWidth)
    $pdf rectangle $x $y $sw [expr {$CFG(fieldH) + 2}]
    ::pdf4tcllib::tag::artifactEnd $pdf

    # The title heads the section it opens.
    $pdf setFont $CFG(fontSizeSection) [_family bold]
    lassign $CFG(labelColor) tr tg tb
    $pdf setFillColor $tr $tg $tb
    set textY [expr {$y + $CFG(fieldH) - 2}]
    ::pdf4tcllib::tag::begin $pdf H2
    ::pdf4tcllib::unicode::safeText $pdf $title -x [expr {$x + 4}] -y $textY
    ::pdf4tcllib::tag::end $pdf

    $pdf setFillColor 0 0 0
    $pdf setStrokeColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y [expr {$CFG(fieldH) + 2 + $CFG(sectionGap)}]
}

# -- labelField ----------------------------------------------

proc ::pdf4tcllib::form::labelField {pdf ctx yVar label ftype args} {
    # Draws a label and a form field side by side and advances yVar by one
    # row height.
    #
    # label  - the caption
    # ftype  - field type: text password checkbox combobox listbox
    #          radiobutton pushbutton signature
    # args   - options passed on to addForm (-id, -init, -options, ...)
    #          plus: -labelw (label width, default from CFG)
    #                -fieldw (field width, default: the rest of the text width)
    #                -fieldh (field height, default from CFG)
    upvar 1 $yVar y
    variable CFG

    set x   [dict get $ctx SX]
    set sw  [dict get $ctx SW]

    # Eigene Optionen extrahieren
    set labelW $CFG(labelW)
    set fieldH $CFG(fieldH)
    set fieldW [expr {$sw - $labelW - $CFG(labelGap)}]
    set passArgs {}

    foreach {k v} $args {
        switch -- $k {
            -labelw { set labelW $v }
            -fieldw { set fieldW $v }
            -fieldh { set fieldH $v }
            default { lappend passArgs $k $v }
        }
    }

    # A form field is an annotation; outside a structure element it cannot be
    # reached from the tree. /Form is the type ISO 32000-1 table 337 gives for
    # an interactive field, and the label is the alternate text a sighted
    # reader sees anyway.
    #
    # The label text goes INSIDE the same element: it belongs to the field
    # it names, and content outside every element is content a reader
    # cannot place. Measured before this changed: one untagged painting
    # operation per label -- a field with no visible name attached to it.
    ::pdf4tcllib::tag::begin $pdf Form -alt $label

    $pdf setFont $CFG(fontSizeLabel) [_family]
    lassign $CFG(labelColor) lr lg lb
    $pdf setFillColor $lr $lg $lb
    set textY [expr {$y + $fieldH - 2}]
    ::pdf4tcllib::unicode::safeText $pdf $label -x $x -y $textY

    $pdf setFont $CFG(fontSize) [_family]
    set fx [expr {$x + $labelW + $CFG(labelGap)}]
    $pdf addForm $ftype $fx $y $fieldW $fieldH {*}$passArgs
    ::pdf4tcllib::tag::end $pdf

    $pdf setFillColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y [expr {$fieldH + $CFG(rowGap)}]
}

# -- row -----------------------------------------------------

proc ::pdf4tcllib::form::row {pdf ctx yVar fields} {
    # Draws several label/field pairs side by side in one row.
    #
    # fields is a list of dicts with:
    #   label   - the caption
    #   type    - field type (text checkbox combobox ...)
    #   width   - total width, label plus field
    #   id      - field id (optional)
    #   init    - initial value (optional)
    #   options - option list for addForm (optional)
    #   labelw  - label width (optional, default from CFG)
    #   fieldh  - field height (optional, default from CFG)
    #
    # Example:
    #   pdf4tcllib::form::row $pdf $ctx y {
    #       {label "Name:"   type text width 220 id f_name}
    #       {label "Datum:"  type text width 100 id f_date}
    #   }
    upvar 1 $yVar y
    variable CFG

    set startX [dict get $ctx SX]
    set x $startX
    set maxH $CFG(fieldH)

    foreach fdef $fields {
        set label   [pdf4tcllib::_dictGetdef $fdef label   ""]
        set ftype   [pdf4tcllib::_dictGetdef $fdef type    text]
        set totalW  [pdf4tcllib::_dictGetdef $fdef width   100]
        set fieldH  [pdf4tcllib::_dictGetdef $fdef fieldh  $CFG(fieldH)]
        set gap     [pdf4tcllib::_dictGetdef $fdef gap     $CFG(labelGap)]

        # Label column: an explicit labelw wins; otherwise fit the label
        # text. In a row short labels are packed tightly -- the fixed
        # stacked-layout column CFG(labelW) would be too wide here and, at
        # a small width, would squeeze the field to zero or negative, so
        # that the field overwrote the next label.
        if {[dict exists $fdef labelw]} {
            set labelW [dict get $fdef labelw]
        } elseif {$label eq ""} {
            set labelW 0
        } else {
            set labelW [expr {[pdf4tcllib::text::width $label \
                $CFG(fontSizeLabel) $CFG(fontFamily)] + 6}]
        }

        if {$fieldH > $maxH} { set maxH $fieldH }

        # addForm-Optionen zusammenbauen
        set addArgs {}
        if {[dict exists $fdef id]}      { lappend addArgs -id      [dict get $fdef id] }
        if {[dict exists $fdef init]}    { lappend addArgs -init    [dict get $fdef init] }
        if {[dict exists $fdef options]} { lappend addArgs -options [dict get $fdef options] }
        if {[dict exists $fdef readonly]} { lappend addArgs -readonly [dict get $fdef readonly] }
        if {[dict exists $fdef multiline]} { lappend addArgs -multiline [dict get $fdef multiline] }
        # Appearance / calculation / formatting / raw JS (pdf4tcl 0.9.4.30+ / .32+ / .33+ / .34+)
        foreach k {align color borderwidth bordercolor bgcolor calculate format js} {
            if {[dict exists $fdef $k]} { lappend addArgs -$k [dict get $fdef $k] }
        }

        set fieldW [expr {$totalW - $labelW - $gap}]
        if {$fieldW < 12} { set fieldW 12 }

        # Label and field in ONE Form element: the caption belongs to the
        # field it names. Outside, it was content a reader cannot place --
        # measured as one untagged painting operation per field.
        ::pdf4tcllib::tag::begin $pdf Form -alt $label

        if {$label ne ""} {
            $pdf setFont $CFG(fontSizeLabel) [_family]
            lassign $CFG(labelColor) lr lg lb
            $pdf setFillColor $lr $lg $lb
            set textY [expr {$y + $fieldH - 2}]
            ::pdf4tcllib::unicode::safeText $pdf $label -x $x -y $textY
        }

        $pdf setFont $CFG(fontSize) [_family]
        set fx [expr {$x + $labelW + $gap}]
        $pdf addForm $ftype $fx $y $fieldW $fieldH {*}$addArgs
        ::pdf4tcllib::tag::end $pdf

        # Next pair: at least totalW, but never less than what was
        # actually used -- that is what prevents an overlap after the
        # field was clamped.
        set consumed [expr {$labelW + $gap + $fieldW}]
        set x [expr {$x + max($totalW, $consumed) + $CFG(labelGap)}]
    }

    $pdf setFillColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y [expr {$maxH + $CFG(rowGap)}]
}

# -- separator -----------------------------------------------

proc ::pdf4tcllib::form::separator {pdf ctx yVar {gap 4}} {
    # Draws a horizontal rule and advances y.
    upvar 1 $yVar y
    variable CFG

    set x  [dict get $ctx SX]
    set sw [dict get $ctx SW]

    # A rule means nothing, it separates visually -- artifact.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    lassign $CFG(lineColor) r g b
    $pdf setStrokeColor $r $g $b
    $pdf setLineWidth $CFG(lineWidth)
    $pdf line $x $y [expr {$x + $sw}] $y
    $pdf setStrokeColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf

    ::pdf4tcllib::page::_advance $ctx y $gap
}

# -- orderTable ----------------------------------------------

proc ::pdf4tcllib::form::orderTable {pdf ctx yVar headers colWidths \
                                      {data {}} args} {
    # Draws an order table with a header row and data rows.
    # Empty rows are appended at the end when -emptyRows is given.
    #
    # headers    - list of column headers
    # colWidths  - list of column widths in points (sum <= SW)
    # data       - list of rows, each row a list of cell values
    # args:
    #   -emptyRows N   number of extra empty rows (default 0)
    #   -rowh      N   row height (default from CFG)
    #   -headerBg  {r g b}  header background colour
    #   -cellForm  idPrefix  cells as fillable AcroForm text fields
    #                        (id = idPrefix_row_column). Without: static text.
    #   -cellOpts  {col {addForm-opts} ...}  extra options per column, with -cellForm only
    upvar 1 $yVar y
    variable CFG

    # Optionen
    set emptyRows 0
    set rowH $CFG(fieldH)
    set headerBg {0.20 0.30 0.50}
    set cellForm ""
    set cellOpts {}
    foreach {k v} $args {
        switch -- $k {
            -emptyRows { set emptyRows $v }
            -rowh      { set rowH $v }
            -headerBg  { set headerBg $v }
            -cellForm  { set cellForm $v }
            -cellOpts  { set cellOpts $v }
            default    { error "orderTable: unknown option $k" }
        }
    }

    set x  [dict get $ctx SX]

    # The doc says "sum <= SW" and until now nothing checked it. Measured
    # 2026-08-15: two columns of SW each drew a table whose right edge sat
    # at 1020 pt on a 595 pt page -- valid PDF, invisible content, no
    # complaint from anyone. Half a point of tolerance for rounding.
    set wantW 0.0
    foreach cw $colWidths { set wantW [expr {$wantW + $cw}] }
    set haveW [dict get $ctx SW]
    if {$wantW > $haveW + 0.5} {
        error "orderTable: column widths total [format %.1f $wantW] pt,\
                the text width is only [format %.1f $haveW] pt --\
                the table would be drawn past the edge of the page"
    }
    if {[llength $colWidths] < [llength $headers]} {
        error "orderTable: [llength $headers] header(s) but only\
                [llength $colWidths] column width(s)"
    }

    # Header row
    lassign $headerBg hr hg hb
    $pdf setFillColor $hr $hg $hb
    set totalW [::tcl::mathop::+ {*}$colWidths]
    $pdf rectangle $x $y $totalW [expr {$rowH + 2}] -filled 1

    $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamilyBold)
    $pdf setFillColor 1 1 1
    set cx $x
    foreach header $headers cw $colWidths {
        if {$header eq "" || $cw eq ""} continue
        set textY [expr {$y + $rowH - 2}]
        ::pdf4tcllib::unicode::safeText $pdf $header -x [expr {$cx + 3}] -y $textY
        set cx [expr {$cx + $cw}]
    }

    $pdf setFillColor 0 0 0
    lassign $CFG(fieldBorder) fr fg fb
    $pdf setStrokeColor $fr $fg $fb
    $pdf setLineWidth $CFG(lineWidth)
    $pdf rectangle $x $y $totalW [expr {$rowH + 2}]

    ::pdf4tcllib::page::_advance $ctx y [expr {$rowH + 2}]

    # Data rows plus empty rows, in one loop; -cellForm makes AcroForm fields
    set nData [llength $data]
    set nRows [expr {$nData + $emptyRows}]
    for {set r 0} {$r < $nRows} {incr r} {
        # Zebra-Streifen
        if {$r % 2 == 1} {
            $pdf setFillColor 0.95 0.95 0.95
            $pdf rectangle $x $y $totalW $rowH -filled 1
            $pdf setFillColor 0 0 0
        }

        set row {}
        if {$r < $nData} { set row [lindex $data $r] }

        if {$cellForm eq ""} {
            $pdf setFont $CFG(fontSize) [_family]
        }
        set cx $x
        set colIdx 0
        foreach cw $colWidths {
            if {$cw eq ""} { incr colIdx; continue }
            set cell ""
            if {$colIdx < [llength $row]} { set cell [lindex $row $colIdx] }
            if {$cellForm ne ""} {
                set pad 2
                set fw [expr {$cw - 2 * $pad}]
                set fh [expr {$rowH - 2 * $pad}]
                if {$fw < 8} { set fw 8 }
                if {$fh < 8} { set fh 8 }
                set copt {}
                if {[dict exists $cellOpts $colIdx]} {
                    set copt [dict get $cellOpts $colIdx]
                }
                # In a table cell the column header is the useful alternate
                # text -- a reader already knows which row it is in.
                set cellAlt [lindex $headers $colIdx]
                if {$cellAlt eq ""} { set cellAlt "Eingabefeld" }
                ::pdf4tcllib::tag::begin $pdf Form -alt $cellAlt
                $pdf addForm text [expr {$cx + $pad}] [expr {$y + $pad}] $fw $fh \
                    -id "${cellForm}_${r}_${colIdx}" -init $cell {*}$copt
                ::pdf4tcllib::tag::end $pdf
            } elseif {$cell ne ""} {
                ::pdf4tcllib::unicode::safeText $pdf [string range $cell 0 40] \
                    -x [expr {$cx + 3}] -y [expr {$y + $rowH - 2}]
            }
            set cx [expr {$cx + $cw}]
            incr colIdx
        }

        $pdf setStrokeColor $fr $fg $fb
        $pdf rectangle $x $y $totalW $rowH
        ::pdf4tcllib::page::_advance $ctx y $rowH
    }

    $pdf setStrokeColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y $CFG(rowGap)
}

# -- sumLine -------------------------------------------------

proc ::pdf4tcllib::form::sumLine {pdf ctx yVar colWidths label value args} {
    # Draws a total row at the end of an order table.
    # label and value are set right-aligned in the last two columns.
    #
    # Without options: value is static text.
    # With -id: the value cell becomes a right-aligned AcroForm text field
    #   (optionally with -calculate {op {fields}} for a live total, and
    #   -init as a static value up front). -calculate needs pdf4tcl
    #   0.9.4.32+.
    upvar 1 $yVar y
    variable CFG

    set fid ""
    set calc ""
    set finit ""
    set ffmt ""
    set fjs ""
    foreach {k v} $args {
        switch -- $k {
            -id        { set fid $v }
            -calculate { set calc $v }
            -init      { set finit $v }
            -format    { set ffmt $v }
            -js        { set fjs $v }
            default    { error "sumLine: unknown option $k" }
        }
    }

    set x      [dict get $ctx SX]
    set rowH   $CFG(fieldH)
    set totalW [::tcl::mathop::+ {*}$colWidths]

    # Hintergrund
    $pdf setFillColor 0.88 0.88 0.88
    $pdf rectangle $x $y $totalW $rowH -filled 1
    $pdf setFillColor 0 0 0

    # Label
    $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamilyBold)
    set labelX [expr {$x + $totalW - [lindex $colWidths end] \
                       - [lindex $colWidths end-1] - 4}]
    set textY  [expr {$y + $rowH - 2}]
    ::pdf4tcllib::unicode::safeText $pdf $label -x $labelX -y $textY -align right

    # Value: static text, or a calculated field when -id is given
    if {$fid ne ""} {
        set lastW [lindex $colWidths end]
        set pad 2
        set fw [expr {$lastW - 2 * $pad}]
        set fh [expr {$rowH - 2 * $pad}]
        if {$fw < 8} { set fw 8 }
        if {$fh < 8} { set fh 8 }
        set fx [expr {$x + $totalW - $lastW + $pad}]
        set aa {}
        if {$calc ne ""} { lappend aa -calculate $calc }
        if {$ffmt ne ""} { lappend aa -format $ffmt }
        if {$fjs ne ""}  { lappend aa -js $fjs }
        ::pdf4tcllib::tag::begin $pdf Form -alt $label
        $pdf addForm text $fx [expr {$y + $pad}] $fw $fh \
            -id $fid -align right -init $finit {*}$aa
        ::pdf4tcllib::tag::end $pdf
    } else {
        $pdf setFont $CFG(fontSize) [_family]
        set valX [expr {$x + $totalW - 4}]
        ::pdf4tcllib::unicode::safeText $pdf $value -x $valX -y $textY -align right
    }

    lassign $CFG(fieldBorder) fr fg fb
    $pdf setStrokeColor $fr $fg $fb
    $pdf setLineWidth $CFG(lineWidth)
    $pdf rectangle $x $y $totalW $rowH
    $pdf setStrokeColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y [expr {$rowH + $CFG(rowGap)}]
}

# ============================================================
# Ende pdf4tcllib::form
# ============================================================


# ============================================================
# Ende pdf4tcllib 0.2
# Tablelist-Export: package require pdf4tcltable
# TextWidget-Export: package require pdf4tcltext
# ============================================================


# --- Unicode-safe bookmark/metadata titles -------------------------------
# pdf4tcl's ::pdf4tcl::SafeQuoteString replaces every codepoint > U+00FF with
# "?" (a Tcl-9 binary-channel workaround). That breaks em dash, typographic
# quotes, Greek, etc. in PDF bookmark titles and document metadata -- visible
# in a viewer's outline (e.g. Okular). As the Unicode-safety layer over
# pdf4tcl, pdf4tcllib installs a Unicode-correct version (UTF-16BE hex string
# with BOM) once pdf4tcl is loaded. Idempotent; pdf4tcl itself stays untouched.
namespace eval ::pdf4tcllib { variable _unicodeTitlesInstalled 0 }
proc ::pdf4tcllib::_installUnicodeTitles {} {
    variable _unicodeTitlesInstalled
    if {$_unicodeTitlesInstalled} return
    if {[info commands ::pdf4tcl::SafeQuoteString] eq ""} return
    proc ::pdf4tcl::SafeQuoteString {string} {
        if {[regexp {[^\x00-\xFF]} $string]} {
            set hex "FEFF"
            foreach ch [split $string ""] {
                scan $ch %c cp
                if {$cp > 0xFFFF} {
                    set cp [expr {$cp - 0x10000}]
                    append hex [format %04X [expr {0xD800 + ($cp >> 10)}]]
                    append hex [format %04X [expr {0xDC00 + ($cp & 0x3FF)}]]
                } else {
                    append hex [format %04X $cp]
                }
            }
            return "<$hex>"
        }
        return [::pdf4tcl::QuoteString $string]
    }
    set _unicodeTitlesInstalled 1
}
# Try once at load time (no-op if pdf4tcl is not yet present -- the
# fonts::init hook installs it later, after pdf4tcl is required).
::pdf4tcllib::_installUnicodeTitles
