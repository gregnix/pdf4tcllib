# pdf4tcllib -- Extension library for pdf4tcl
#
# Copyright (c) 2026 Gregor (gregnix)
# BSD 2-Clause License -- see LICENSE for details
#
# Provides: fonts, unicode, text, table, page, drawing,
#           units, image, form namespaces
# Requires: pdf4tcl 0.9.4.23+, Tcl 8.6+

# pdf4tcllib-0.1.tm -- Extension library for pdf4tcl
#
# Single file: all modules in one file. (2544 lines)
# No external dependencies except pdf4tcl itself.
#
# Modules (as namespaces):
#   pdf4tcllib::units    Unit conversion
#   pdf4tcllib::fonts    Font management (TTF + fallback)
#   pdf4tcllib::unicode  Unicode sanitization
#   pdf4tcllib::text     Text layout (wrapping, width, tabs)
#   pdf4tcllib::page     Page numbers, header/footer
#   pdf4tcllib::table    Table rendering
#   pdf4tcllib::drawing  Drawing functions
#   pdf4tcllib::image    Image integration (Tk)
#   pdf4tcllib::form     Form helpers for addForm (Label+Field, rows, tables)
#
# Usage:
#   package require pdf4tcllib 0.1
#   pdf4tcllib::fonts::init
#   set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
#   $pdf startPage
#   $pdf setFont 12 [pdf4tcllib::fonts::fontSans]
#   pdf4tcllib::unicode::safeText $pdf "Text" -x 50 -y 50
#   $pdf write -file out.pdf
#   $pdf destroy

package require Tcl 8.6-
package provide pdf4tcllib 0.3

namespace eval ::pdf4tcllib {
    variable version 0.3
}

proc ::pdf4tcllib::version {} {
    variable version
    return $version
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

    # CID-Mode merken (fuer sanitize-Filter)
    variable cidMode
    set cidMode $opt(-cid)

    if {$ready && !$opt(-force)} { return }

    # -- Search for TTF files --
    set family $opt(-family)
    set ttfRegular   ""
    set ttfBold      ""
    set ttfItalic    ""
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
        puts stderr "pdf4tcllib::fonts: Gesucht in:"
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

        # Helper: ein FontSpec registrieren, je nach $cidMode entweder
        # 256-Char-Encoding (klein) oder CID-Encoding (volles Unicode).
        # Vorteil CID: Greek, Math-Symbole, beliebige Unicode-Punkte gehen.
        # Nachteil: PDF ist groesser (TTF wird komplett eingebettet).
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
                puts stderr "pdf4tcllib::fonts: TTF-Italic-Fonts geladen"
            } errI]} {
                set fontSansItalic     "Helvetica-Oblique"
                set fontSansBoldItalic "Helvetica-BoldOblique"
                puts stderr "pdf4tcllib::fonts: TTF-Italic Fehler: $errI -- Fallback Helvetica-Oblique"
            }
        } else {
            set fontSansItalic     "Helvetica-Oblique"
            set fontSansBoldItalic "Helvetica-BoldOblique"
        }

        puts stderr "pdf4tcllib::fonts: TTF-Fonts geladen from [file dirname $ttfRegular]"

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
    # Setzt Font mit optionalem Style-String.
    # style: "" | Bold | Italic | BoldItalic | Oblique | BoldOblique
    #
    # Konvertiert Style-Strings in Font-Namen:
    #   Helvetica + Bold      -> Helvetica-Bold
    #   Helvetica + Italic    -> Helvetica-Oblique
    #   Times-Roman + Bold    -> Times-Bold
    #   Courier + Italic      -> Courier-Oblique
    #
    # Fuer TTF-Fonts (geladen via fonts::init):
    #   style Bold    -> fontSansBold
    #   style Italic  -> fontSansItalic
    #   style BoldItalic -> fontSansBoldItalic
    if {$style eq ""} {
        $pdf setFont $size $family
        return
    }

    # TTF-Fonts wenn geladen
    if {[ready]} {
        switch -- $style {
            Bold        { $pdf setFont $size [fontSansBold]; return }
            Italic      { $pdf setFont $size [fontSansItalic]; return }
            BoldItalic  { $pdf setFont $size [fontSansBoldItalic]; return }
        }
    }

    # Standard-Font Stil-Mapping
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

    # 2. Relativ zum Modul
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
    # macOS (auch unix, but extra)
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

    # Erweiterte Symbole (32 Stueck)
    # Jeder Wert MUSS als Integer (nicht String) gespeichert werden!
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


namespace eval ::pdf4tcllib::unicode {}

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

        # Surrogate-Paar erkennen (Tcl 8.6 Emoji-Handling)
        if {$cp >= 0xD800 && $cp <= 0xDBFF} {
            # High surrogate — after Low surrogate schauen
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
            # TTF-Modus: Subset-Filter nur im klassischen 256-Char-Encoding.
            # Im CID-Mode (full Unicode) wird alles durchgelassen -- pdf4tcl
            # kuemmert sich um Glyph-Lookup und mappt unbekannte Codepoints
            # selbst auf .notdef.
            if {[::pdf4tcllib::fonts::isCidMode]} {
                append result $c
            } elseif {[::pdf4tcllib::fonts::inSubset $cp]} {
                append result $c
            } else {
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
    # Replaces 4-Byte UTF-8 Sequenzen (Emoji, BMP+) durch ASCII-Fallbacks.
    #
    # MUST be called on BINARY data BEFORE Tcl corrupts the bytes
    # in seinen internen String konvertiert (encoding convertfrom).
    #
    # Tcl 8.6 kann Codepoints > U+FFFF not render und
    # konvertiert sie zu U+FFFD. Diese Funktion faengt die
    # rohen UTF-8 Bytes vorher ab.
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
    # Returns Text sicher an pdf4tcl aus.
    # Sanitized den Text and faengt error ab.
    #
    # Argumente:
    #   pdf   - pdf4tcl-Objekt
    #   txt   - Auszugebender Text
    #   args  - Werden an $pdf text weitergereicht (-x, -y, -align, ...)
    #
    # Optionale Steuerung:
    #   -mono 0/1   Wird from args extrahiert and an sanitize durchgereicht

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

    if {[catch {$pdf text $clean {*}$passArgs} err]} {
        # Notfall: Alles on druckbares ASCII reduzieren
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
        catch {$pdf text $safe {*}$passArgs}
    }
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

proc ::pdf4tcllib::text::wrap {line maxW fontSize fontName {codeContinuation 0} {pdf {}} {hardBreak 0}} {
    # Wraps a line at word boundaries.
    #
    # Returns a list of sub-lines that each fit within maxW.
    # hardBreak 0 (default): over-wide words are truncated (unchanged legacy
    #   behaviour). hardBreak 1: over-wide words are broken character-wise so
    #   nothing is lost (needed for table cells with long path/dotted tokens).
    #
    # codeContinuation: if 1, wrapped code lines get
    # with " \" am Ende markiert (Tcl-Stil).

    if {[width $line $fontSize $fontName] <= $maxW} {
        return [list $line]
    }

    # Bei Code-Continuation Platz for " \" reservieren
    if {$codeContinuation} {
        set wrapMaxW [expr {$maxW - [width " \\" $fontSize $fontName]}]
    } else {
        set wrapMaxW $maxW
    }

    set words [split $line " "]
    set lines {}
    set current ""

    foreach word $words {
        if {$current eq ""} {
            set test $word
        } else {
            set test "$current $word"
        }

        if {[width $test $fontSize $fontName] <= $wrapMaxW} {
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

proc ::pdf4tcllib::text::writeParagraph {pdf text x y width {size 12} {align left}} {
    # Writes a paragraph with automatic line wrapping.
    # Returns the next Y position after the last rendered line.
    #
    # Uses drawTextBox -newyvar (pdf4tcl 0.9.4.23+) for exact Y position.
    # Fallback: line count estimation for older pdf4tcl.

    $pdf setFont $size Helvetica

    # Try new API: -newyvar gives exact Y after last line (0.9.4.23+)
    set nextY 0
    if {![catch {
        $pdf drawTextBox $x $y $width 10000 $text \
            -align $align \
            -newyvar nextY
    }]} {
        return $nextY
    }

    # Fallback: linesvar + lineheight estimation
    set lh [::pdf4tcllib::page::lineheight $size]
    set lines_var ::pdf4tcllib::text::_temp_lines
    $pdf drawTextBox $x $y $width 10000 $text \
        -align $align \
        -linesvar $lines_var

    if {[info exists $lines_var]} {
        set num_lines [set $lines_var]
    } else {
        set num_lines [expr {[string length $text] / 50 + 1}]
    }
    return [expr {$y + $num_lines * $lh}]
}


# ----------------------------------------------------------------
# Math-Inline-Helpers (Subset, kein vollstaendiges LaTeX)
# ----------------------------------------------------------------
# Pragmatischer Ansatz: Sub/Super via y-Offset + reduzierte Fontgroesse,
# plus eine Lookup-Tabelle fuer haeufige LaTeX-Symbol-Namen -> Unicode.
#
# Damit lassen sich Inline-Math wie $x^2$, $H_2O$, $\alpha + \beta$
# direkt in PDFs rendern. Komplexere Konstrukte (Brueche, Wurzeln,
# Integrale-Limits) brauchen externe Renderer (KaTeX-CLI -> SVG,
# eingebettet via Image).
#
# Konventionen pdf4tcl-text:
#   $pdf text $str -x $x -y $y -font $font
# y ist die Baseline. Fuer Superscript verschieben wir nach oben
# (negativ in PDF-Y-Koordinaten? -- in pdf4tcl ist y top-down, also
# subtrahieren wir vom y-Wert um nach oben zu kommen).

proc ::pdf4tcllib::text::superscript {pdf textStr x y fontSize fontName} {
    # Zeichnet textStr als Hochstellung. Reduziert Fontgroesse auf 70%
    # und shift Baseline um 35% der Original-Fontgroesse nach oben.
    # Returnt die Pixel-Breite des gezeichneten Textes (fuer X-Advance).
    set smallSize [expr {$fontSize * 0.7}]
    set yShift    [expr {$fontSize * 0.35}]
    set ySuper    [expr {$y - $yShift}]
    $pdf setFont $smallSize $fontName
    $pdf text $textStr -x $x -y $ySuper
    set w [$pdf getStringWidth $textStr]
    # Font wiederherstellen (caller-Verantwortung wenn anders erwartet)
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
# Subset der haeufigsten Math-Symbole. Erweitern nach Bedarf.
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
    # Liefert das Unicode-Zeichen zu einem LaTeX-Symbol-Namen.
    # Beispiele:
    #   text::mathSymbol alpha   -> \u03B1
    #   text::mathSymbol cdot    -> \u00B7
    #   text::mathSymbol unknown -> "" (kein Throw, damit Aufrufer
    #                                   einfach Fallback rendern kann)
    variable _mathSymbols
    if {[dict exists $_mathSymbols $name]} {
        return [dict get $_mathSymbols $name]
    }
    return ""
}

proc ::pdf4tcllib::text::mathSymbolNames {} {
    # Liefert eine sortierte Liste aller bekannten Symbol-Namen.
    # Nuetzlich fuer Dokumentation, Tab-Completion, Tests.
    variable _mathSymbols
    return [lsort [dict keys $_mathSymbols]]
}


# ================================================================
# Module: pdf4tcllib::math
# ================================================================
#
# pdf4tcllib::math -- Inline-Math-Rendering im PDF
#
# Inspiriert von Arjen Markus' "MathFormula" auf wiki.tcl-lang.org
# (Rendering mathematical formulae, 2002-2007). Portierung der Notation
# auf pdf4tcl-basierte PDF-Ausgabe statt Tk-Canvas.
#
# Notation -- jedes Token whitespace-separiert:
#   alpha beta gamma   griechische Buchstaben (LaTeX-Stil, klein)
#   Alpha Beta Sigma   griechische Grossbuchstaben
#   x ^ 2              Superscript (x mit hoch 2)
#   H _ 2 O            Subscript (H mit tief 2, dann O)
#   ~                  forced space
#   SUM PROD INT       grosse Operatoren
#   from ... to ...    Limits unter/ueber SUM/INT/PROD
#   infty sqrt cdot    Math-Symbole (siehe text::mathSymbolNames)
#
# Beispiele:
#   "alpha + beta = gamma"
#   "x ^ 2 + y ^ 2 = r ^ 2"
#   "SUM from i=0 to infty ~ a _ i"
#   "INT from 0 to pi cos ^ 2 x dx"
#
# Public API:
#   pdf4tcllib::math::renderFormula pdf x y formula ?-size N? ?-font NAME?
#       Rendert formula bei (x,y) ins PDF. Returnt End-X-Position.
#
#   pdf4tcllib::math::analyseFormula formula
#       Tokenisiert formula. Returnt Liste von {token xp yp advance}.
#       Nuetzlich fuer eigene Renderer.
#
# Voraussetzungen:
#   pdf4tcllib::fonts::init -cid 1   -- fuer Greek + Math-Symbole

namespace eval ::pdf4tcllib::math {
    namespace export renderFormula analyseFormula
}

# ----------------------------------------------------------------
# analyseFormula -- Token-Parser
# ----------------------------------------------------------------
proc ::pdf4tcllib::math::analyseFormula {formula} {
    set result  [list]
    set advance 1
    set xp      0
    set yp      0
    # Limit-Offsets fuer SUM/INT/PROD (werden von from/to genutzt)
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
                # Wer das Pfeil-Symbol -> braucht: "rightarrow" verwenden
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
        # Default: erst TTF-Sans (wenn da), sonst Helvetica
        if {[::pdf4tcllib::fonts::hasTtf]} {
            set font [::pdf4tcllib::fonts::fontSans]
        } else {
            set font Helvetica
        }
    }

    set tokens [analyseFormula $formula]
    set xpos $x

    foreach {token xp yp advance} $tokens {
        # 1. Symbol-Lookup
        #    - Erst direkt (alpha -> α, le -> ≤)
        #    - SUM/INT/PROD: lowercase-Variante fuer Symbol-Lookup
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

        # 2. Position berechnen (xp/yp relativ zum aktuellen Cursor)
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

        # 4. X-Cursor weiter, wenn advance=1
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
    namespace export renderLatex measureLatex
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
proc ::pdf4tcllib::math::_latexMeasureList {pdf font size atoms} {
    set w 0.0; set h [expr {$size*0.7}]; set d [expr {$size*0.2}]
    foreach a $atoms {
        lassign [_latexMeasureAtom $pdf $font $size $a] aw ah ad
        set w [expr {$w + $aw}]
        if {$ah > $h} { set h $ah }
        if {$ad > $d} { set d $ad }
    }
    return [list $w $h $d]
}

proc ::pdf4tcllib::math::_latexMeasureAtom {pdf font size a} {
    set kind [lindex $a 0]
    switch -- $kind {
        sym {
            set g [lindex $a 1]
            $pdf setFont $size $font
            return [list [$pdf getStringWidth $g] [expr {$size*0.72}] [expr {$size*0.20}]]
        }
        space { return [list [expr {$size*0.3}] 0 0] }
        grp   { return [_latexMeasureList $pdf $font $size [lindex $a 1]] }
        scripted {
            lassign $a _ base sub sup
            lassign [_latexMeasureAtom $pdf $font $size $base] bw bh bd
            set ss [expr {$size*0.7}]
            set sw 0.0; set extraH 0; set extraD 0
            if {[llength $sup]} {
                lassign [_latexMeasureList $pdf $font $ss $sup] supw suph supd
                if {$supw>$sw} { set sw $supw }
                set extraH [expr {$bh*0.5}]
            }
            if {[llength $sub]} {
                lassign [_latexMeasureList $pdf $font $ss $sub] subw subh subd
                if {$subw>$sw} { set sw $subw }
                set extraD [expr {$bd+$ss*0.4}]
            }
            return [list [expr {$bw+$sw}] [expr {$bh+$extraH}] [expr {$bd+$extraD}]]
        }
        frac {
            lassign $a _ num den
            lassign [_latexMeasureList $pdf $font [expr {$size*0.85}] $num] nw nh nd
            lassign [_latexMeasureList $pdf $font [expr {$size*0.85}] $den] dw dh dd
            return [list [expr {max($nw,$dw)+4}] [expr {$nh+$nd+2+$size*0.3}] [expr {$dh+$dd+2}]]
        }
        sqrt {
            lassign $a _ arg
            lassign [_latexMeasureList $pdf $font $size $arg] aw ah ad
            return [list [expr {$aw+$size*0.7+2}] [expr {$ah+2}] $ad]
        }
        bigop {
            return [list [expr {$size*1.1}] [expr {$size*1.0}] [expr {$size*1.05}]]
        }
    }
    return [list 0 0 0]
}

# ---- Draw (baseline at $y; returns advance x) ----
proc ::pdf4tcllib::math::_latexDrawList {pdf font size x y atoms} {
    set cx $x
    foreach a $atoms {
        set cx [_latexDrawAtom $pdf $font $size $cx $y $a]
    }
    return $cx
}

proc ::pdf4tcllib::math::_latexDrawAtom {pdf font size x y a} {
    set kind [lindex $a 0]
    switch -- $kind {
        sym {
            set g [lindex $a 1]
            $pdf setFont $size $font
            $pdf text $g -x $x -y $y
            return [expr {$x+[$pdf getStringWidth $g]}]
        }
        space { return [expr {$x+$size*0.3}] }
        grp   { return [_latexDrawList $pdf $font $size $x $y [lindex $a 1]] }
        scripted {
            lassign $a _ base sub sup
            set bx [_latexDrawAtom $pdf $font $size $x $y $base]
            set ss [expr {$size*0.7}]
            if {[llength $sup]} { _latexDrawList $pdf $font $ss $bx [expr {$y-$size*0.45}] $sup }
            if {[llength $sub]} { _latexDrawList $pdf $font $ss $bx [expr {$y+$size*0.28}] $sub }
            lassign [_latexMeasureAtom $pdf $font $size $a] aw ah ad
            return [expr {$x+$aw}]
        }
        frac {
            lassign $a _ num den
            set fs [expr {$size*0.85}]
            lassign [_latexMeasureList $pdf $font $fs $num] nw nh nd
            lassign [_latexMeasureList $pdf $font $fs $den] dw dh dd
            set w [expr {max($nw,$dw)+4}]
            set midY [expr {$y-$size*0.25}]
            _latexDrawList $pdf $font $fs [expr {$x+($w-$nw)/2.0}] [expr {$midY-2-$nd}] $num
            _latexDrawList $pdf $font $fs [expr {$x+($w-$dw)/2.0}] [expr {$midY+2+$dh}] $den
            $pdf setLineWidth 0.6
            $pdf line $x $midY [expr {$x+$w}] $midY
            return [expr {$x+$w}]
        }
        sqrt {
            lassign $a _ arg
            set radW [expr {$size*0.6}]
            lassign [_latexMeasureList $pdf $font $size $arg] aw ah ad
            set topY [expr {$y-$ah}]
            $pdf setLineWidth 0.7
            $pdf line $x [expr {$y-$size*0.25}] [expr {$x+$radW*0.4}] [expr {$y+$ad*0.5}]
            $pdf line [expr {$x+$radW*0.4}] [expr {$y+$ad*0.5}] [expr {$x+$radW*0.65}] $topY
            $pdf line [expr {$x+$radW*0.65}] $topY [expr {$x+$radW+$aw+2}] $topY
            set ax [_latexDrawList $pdf $font $size [expr {$x+$radW+1}] $y $arg]
            return [expr {$ax+1}]
        }
        bigop {
            lassign $a _ op lower upper
            set bs [expr {$size*1.6}]
            $pdf setFont $bs $font
            set g [_latexSymbol $op]
            set ow [$pdf getStringWidth $g]
            lassign [_latexMeasureAtom $pdf $font $size $a] aw ah ad
            $pdf text $g -x [expr {$x+($aw-$ow)/2.0}] -y [expr {$y+$size*0.35}]
            set ls [expr {$size*0.62}]
            if {[llength $upper]} {
                lassign [_latexMeasureList $pdf $font $ls $upper] uw uh ud
                _latexDrawList $pdf $font $ls [expr {$x+($aw-$uw)/2.0}] [expr {$y-$size*0.95}] $upper
            }
            if {[llength $lower]} {
                lassign [_latexMeasureList $pdf $font $ls $lower] lw lh ld
                # under-limit lowered (0.95 -> 1.18) so e.g. \sum_{n=1} is not
                # cramped against the operator; measure depth raised to match.
                _latexDrawList $pdf $font $ls [expr {$x+($aw-$lw)/2.0}] [expr {$y+$size*1.18}] $lower
            }
            return [expr {$x+$aw+1}]
        }
    }
    return $x
}

proc ::pdf4tcllib::math::measureLatex {pdf latex args} {
    # Returns {width heightAboveBaseline depthBelow} for a LaTeX-subset
    # string, so callers can centre or page-fit before renderLatex.
    array set opt {-size 12 -font ""}
    array set opt $args
    set font $opt(-font)
    if {$font eq ""} {
        if {[::pdf4tcllib::fonts::hasTtf]} {
            set font [::pdf4tcllib::fonts::fontSans]
        } else {
            set font Helvetica
        }
    }
    set toks [_latexTokenize $latex]
    set atoms [_latexParseGroup toks]
    return [_latexMeasureList $pdf $font $opt(-size) $atoms]
}

proc ::pdf4tcllib::math::renderLatex {pdf x y latex args} {
    array set opt {-size 12 -font ""}
    array set opt $args
    set font $opt(-font)
    if {$font eq ""} {
        if {[::pdf4tcllib::fonts::hasTtf]} {
            set font [::pdf4tcllib::fonts::fontSans]
        } else {
            set font Helvetica
        }
    }
    set toks [_latexTokenize $latex]
    set atoms [_latexParseGroup toks]
    return [_latexDrawList $pdf $font $opt(-size) $x $y $atoms]
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
        error "Unbekannte Papiergroesse: $paper (erlaubt: [array names paperSizes])"
    }

    lassign $paperSizes($paperKey) pw ph

    if {$opt(-landscape)} {
        set tmp $pw
        set pw $ph
        set ph $tmp
    }

    set margin_pt [::pdf4tcllib::units::mm $opt(-margin)]

    # orient true  = top-left, y wächst nach unten (wie Tk Canvas / HTML)
    #   top    = margin_pt  (kleiner Wert, nahe y=0 oben)
    #   bottom = page_h - margin_pt  (großer Wert, nahe Seitenboden)
    # orient false = bottom-left, y wächst nach oben (Standard-PDF)
    #   top    = page_h - margin_pt  (großer Wert, nahe Seitenoberrand)
    #   bottom = margin_pt  (kleiner Wert, nahe y=0 unten)
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

    $pdf setFont $size Helvetica
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y -align center
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

    $pdf setFont $size Helvetica
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y -align center

    # Trennlinie
    set lx [dict get $ctx left]
    set rx [dict get $ctx right]
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf line $lx $ly $rx $ly
    $pdf setStrokeColor 0 0 0
}

proc ::pdf4tcllib::page::footer {pdf ctx text pageNo {size 9}} {
    # Writes a footer: text left, page number right.
    # Supports both orient true (y down) and orient false (y up).

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

    # Trennlinie
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf line $lx $ly $rx $ly
    $pdf setStrokeColor 0 0 0

    # Text links
    $pdf setFont $size Helvetica
    ::pdf4tcllib::unicode::safeText $pdf $text -x $lx -y $y

    # Seitennummer rechts
    ::pdf4tcllib::unicode::safeText $pdf "Seite $pageNo" -x $rx -y $y -align right
}

proc ::pdf4tcllib::page::centerText {pdf ctx text y {size 12} {font "Helvetica"}} {
    # Writes Text horizontal zentriert.


    set x [expr {[dict get $ctx page_w] / 2.0}]
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

    $pdf setStrokeColor 0.85 0.85 0.85
    $pdf setLineWidth 0.25

    # Vertikale Linien
    for {set x 0} {$x <= $pw} {set x [expr {$x + $spacing}]} {
        $pdf line $x 0 $x $ph
        $pdf setFont 6 Helvetica
        $pdf setFillColor 0.6 0.6 0.6
        $pdf text "[expr {int($x)}]" -x [expr {$x + 2}] -y 8
    }

    # Horizontale Linien
    for {set y 0} {$y <= $ph} {set y [expr {$y + $spacing}]} {
        $pdf line 0 $y $pw $y
        $pdf setFont 6 Helvetica
        $pdf setFillColor 0.6 0.6 0.6
        $pdf text "[expr {int($y)}]" -x 2 -y [expr {$y + 8}]
    }

    $pdf setStrokeColor 0 0 0
    $pdf setFillColor 0 0 0
}

proc ::pdf4tcllib::page::debugGrid {pdf ctx {spacing 50}} {
    # Zeichnet ein Debug-Raster ueber die Seite.
    # Nur aktiv wenn Umgebungsvariable PDF4TCL_DEBUG gesetzt ist.
    #
    # spacing: Rasterabstand in Punkten (Standard: 50pt = ~17.6mm)
    #
    # Verwendung:
    #   pdf4tcllib::page::debugGrid $pdf $ctx
    #   pdf4tcllib::page::debugGrid $pdf $ctx 25   ;# feineres Raster
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
    $pdf setFont 6 Helvetica
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
    $pdf setFont 8 Courier
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


namespace eval ::pdf4tcllib::table {}

# ============================================================
# Oeffentliche API
# ============================================================

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

    set nCols [llength $header]
    if {$nCols == 0 && [llength $rows] > 0} {
        set nCols [llength [lindex $rows 0]]
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
    set rowIdx 0
    foreach row $rows {
        set rH [_rowHeight $row $colWidths $cellPad $fontSize $fontSans $lineH $pdf]

        # Page break, measured against THIS row's real height
        if {$orient ? (($y + $rH) > $yBot) : (($y - $rH) < $yBot)} {
            _drawSegmentLines $pdf $x0 $tableStartY $y $hdrBottom $rowYs $totalW $colWidths
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

        # Zebra-Streifen
        if {$rowIdx % 2 == 1} {
            $pdf setFillColor 0.97 0.97 0.97
            $pdf rectangle $x0 $y $totalW $rH -filled 1
            $pdf setFillColor 0.0 0.0 0.0
        }

        _drawCellsWrapped $pdf $x0 $y $rH $orient $colWidths $aligns $cellPad \
            $fontSize $fontSans $row $lineH
        set y [expr {$orient ? ($y + $rH) : ($y - $rH)}]
        lappend rowYs $y
        incr rowIdx
    }

    # -- Grid lines for the final (or only) page segment --
    _drawSegmentLines $pdf $x0 $tableStartY $y $hdrBottom $rowYs $totalW $colWidths

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
    $pdf setLineWidth 0.5
    $pdf setFillColor 0.88 0.88 0.88
    $pdf rectangle $x0 $y $totalW $hH -filled 1
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setFont $fontSize $fontBold
    _drawCellsWrapped $pdf $x0 $y $hH $orient $colWidths $aligns $cellPad \
        $fontSize $fontBold $header $lineH
    return $hH
}

proc ::pdf4tcllib::table::_drawSegmentLines {pdf x0 tableStartY y hdrBottom rowYs totalW colWidths} {
    # Draws the grid lines for one on-page table segment: top border, header
    # separator (thicker), row separators and the vertical column lines. Called
    # once per page (at each page break and once at the end) so every page of a
    # multi-page table gets a complete frame, not just the last one.
    $pdf setStrokeColor 0.6 0.6 0.6
    $pdf setLineWidth 0.5
    $pdf line $x0 $tableStartY [expr {$x0 + $totalW}] $tableStartY
    if {$hdrBottom ne ""} {
        $pdf setLineWidth 1.0
        $pdf line $x0 $hdrBottom [expr {$x0 + $totalW}] $hdrBottom
        $pdf setLineWidth 0.5
    }
    foreach ly [lrange $rowYs 2 end] {
        $pdf line $x0 $ly [expr {$x0 + $totalW}] $ly
    }
    _drawVLines $pdf $x0 $tableStartY $y $colWidths
}

proc ::pdf4tcllib::table::_isDictFormat {tableData} {
    # Checks ob tableData ein Dict with keys header/rows/aligns ist.
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
    set nCols [llength $header]
    if {$nCols == 0 && [llength $rows] > 0} {
        set nCols [llength [lindex $rows 0]]
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
            set hW [::pdf4tcllib::text::width [lindex $header $i] $fontSize $fontSansBold $pdf]
        }
        set cMax $hW
        foreach row $rows {
            set cw [::pdf4tcllib::text::width [lindex $row $i] $fontSize $fontSans $pdf]
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

proc ::pdf4tcllib::table::_drawCells {pdf x0 y0 cellH colWidths aligns cellPad fontSize fontName texts} {
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
        ::pdf4tcllib::unicode::safeText $pdf $text -x $textX -y $textY
        set x [expr {$x + $colW}]
    }
}

proc ::pdf4tcllib::table::_rowHeight {row colWidths cellPad fontSize fontName lineH pdf} {
    # Measures the height a row needs once each cell is wrapped (hardBreak on)
    # to its inner column width: max wrapped line count over the cells.
    set maxLines 1
    foreach text $row colW $colWidths {
        set availW [expr {$colW - 2 * $cellPad}]
        set n [llength [::pdf4tcllib::text::wrap $text $availW $fontSize $fontName 0 $pdf 1]]
        if {$n > $maxLines} { set maxLines $n }
    }
    return [expr {$maxLines * $lineH + 2 * $cellPad}]
}

proc ::pdf4tcllib::table::_drawCellsWrapped {pdf x0 y rowH orient colWidths aligns cellPad fontSize fontName texts lineH} {
    # Draws one table row with per-cell wrapping (hardBreak on) and alignment,
    # top-aligned within the row band. Honours the orient flag so it works in
    # both top-left (orient=1) and bottom-left (orient=0) coordinate systems.
    set x $x0
    foreach text $texts colW $colWidths align $aligns {
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
    }
    array set opts $args

    set num_cols [llength $col_widths]
    set num_rows [llength $rows]
    set row_height $opts(-row_height)
    set pad $opts(-pad)

    # Total width
    set table_w 0
    foreach w $col_widths { set table_w [expr {$table_w + $w}] }

    # Zebra-Streifen
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

    # Cell contents
    $pdf setFont $opts(-font_size) Helvetica
    for {set r 0} {$r < $num_rows} {incr r} {
        set row [lindex $rows $r]
        set text_y [expr {$y + $r * $row_height + $row_height/2 + $opts(-font_size)/3}]
        set col_x $x
        for {set c 0} {$c < $num_cols} {incr c} {
            set cell_text [lindex $row $c]
            $pdf text $cell_text -x [expr {$col_x + $pad}] -y $text_y
            set col_x [expr {$col_x + [lindex $col_widths $c]}]
        }
    }

    return [expr {$y + $num_rows * $row_height + $pad}]
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
    if {$steps < 1} { set steps 1 }
    set dh [expr {$h / double($steps)}]
    for {set i 0} {$i < $steps} {incr i} {
        set t [expr {$i / double($steps)}]
        set rgb [interpolate $c1 $c2 $t]
        $pdf setFillColor {*}$rgb
        set yy [expr {$y + $i * $dh}]
        $pdf rectangle $x $yy $w $dh -filled 1
    }
}

proc ::pdf4tcllib::drawing::gradient_h {pdf x y w h c1 c2 {steps 100}} {
    # Horizontaler Farbverlauf (links after rechts).
    if {$steps < 1} { set steps 1 }
    set dw [expr {$w / double($steps)}]
    for {set i 0} {$i < $steps} {incr i} {
        set t [expr {$i / double($steps)}]
        set rgb [interpolate $c1 $c2 $t]
        $pdf setFillColor {*}$rgb
        set xx [expr {$x + $i * $dw}]
        $pdf rectangle $xx $y $dw $h -filled 1
    }
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
    # Rechteck mit abgerundeten Ecken.
    # r: Eckradius
    #
    # Optionen:
    #   -clip 1   Pfad als Clipping-Pfad verwenden statt zeichnen.
    #             Nuetzlich um Bilder auf abgerundetes Rect zu beschneiden:
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
        # Clipping-Pfad: polygon-Punkte als Pfad + W n Operatoren
        # (pdf4tcl::clip nimmt nur ein Rechteck -- wir brauchen Pfad-Clip)
        # Implementierung via Pdfout (raw PDF content stream)
        # Da wir keinen Zugriff auf Pdfout haben, nutzen wir gsave + polygon
        # als weisse Fuellung und setzen clip via rawContent wenn verfuegbar
        # Fallback: einfaches Rechteck-Clip
        $pdf clip $x $y $w $h
    } else {
        $pdf polygon {*}$pts -stroke $stroke -filled $fill
    }
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

proc ::pdf4tcllib::drawing::textRotated {pdf txt x y angle size {font Helvetica}} {
    # Rotierter Text.
    # angle: Drehwinkel in Grad (gegen Uhrzeigersinn)
    $pdf setFont $size $font
    if {![catch {$pdf text $txt -x $x -y $y -angle $angle}]} { return }

    # Fallback: characterweise positionieren
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

proc ::pdf4tcllib::drawing::textScaled {pdf txt x y sx sy size {font Helvetica}} {
    # Skalierter Text via gsave/translate/scale/text/grestore.
    # sx: horizontale Skalierung, sy: vertikale Skalierung
    # Koordinaten: x y = Baseline-Position in aktuellen Einheiten

    $pdf setFont $size $font
    $pdf gsave
    $pdf translate $x $y
    $pdf scale $sx $sy
    # Nach scale sind Koordinaten in skalierten Einheiten -- Text bei 0 0
    $pdf text $txt -x 0 -y 0
    $pdf grestore
}

proc ::pdf4tcllib::drawing::textSkewed {pdf txt x y skewX skewY size {font Helvetica}} {
    # Geneigter Text (Pseudo-Italic).
    # skewX, skewY: Neigungswinkel in Grad
    if {![catch {$pdf text $txt -x $x -y $y -skew $skewX $skewY -size $size -font $font}]} { return }

    # Fallback
    set pi [expr {acos(-1)}]
    set tanx [expr {tan($skewX * $pi / 180.0)}]
    set spacing [expr {$size * 0.6}]
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
    # Adds Kreisbogen-Punkte zur Liste hinzu.
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

# Tk is benoetigt for image-Funktionen.
# In GUI-Apps (mdhelp4) immer vorhanden.
catch {package require Tk}

namespace eval ::pdf4tcllib::image {}

# ============================================================
# Oeffentliche API
# ============================================================

proc ::pdf4tcllib::image::insert {pdf tkImg x yVar maxW yTop yBot pageNoVar pageW pageH margin fontSize {debug 0}} {
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
    # Extracts RGB data from a Tk photo image.
    #
    # Returns Liste: width height RGB-Bytes (als Hex)

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
# pdf4tcllib::form -- Formularhilfen fuer addForm
#
# Setzt pdf4tcl::addForm (0.9.4.1+) voraus.
# Bietet Label+Feld in einem Aufruf, Zeilen- und Abschnitts-
# Layout sowie Bestelltabellen relativ zum page::context.
#
# Hinweis: addForm unterstuetzt keine CID-Fonts -- Standard-
# Fonts (Helvetica usw.) verwenden.
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
}

# -- Konfiguration -------------------------------------------

proc ::pdf4tcllib::form::configure {args} {
    # Konfigurations-Optionen setzen oder abfragen.
    # Ohne Argumente: aktuelle Config als Dictionary.
    # Mit -key val Paaren: Werte setzen.
    variable CFG
    if {[llength $args] == 0} {
        return [array get CFG]
    }
    foreach {k v} $args {
        set key [string trimleft $k -]
        if {[info exists CFG($key)]} {
            set CFG($key) $v
        } else {
            error "pdf4tcllib::form::configure: unbekannte Option -$key"
        }
    }
}

# -- fieldHeight ---------------------------------------------

proc ::pdf4tcllib::form::fieldHeight {} {
    # Gibt die konfigurierte Feldhoehe zurueck.
    variable CFG
    return $CFG(fieldH)
}

# -- rowHeight -----------------------------------------------

proc ::pdf4tcllib::form::rowHeight {} {
    # Gibt die Gesamthoehe einer Formularzeile zurueck
    # (Feldhoehe + Zeilenabstand).
    variable CFG
    return [expr {$CFG(fieldH) + $CFG(rowGap)}]
}

# -- section -------------------------------------------------

proc ::pdf4tcllib::form::section {pdf ctx yVar title} {
    # Zeichnet einen Abschnitts-Header (grauer Balken + Titel).
    # Aktualisiert yVar um die Hoehe des Abschnitts + Gap.
    upvar 1 $yVar y
    variable CFG

    set x   [dict get $ctx SX]
    set sw  [dict get $ctx SW]

    # Hintergrundbalken
    lassign $CFG(sectionBg) r g b
    $pdf setFillColor $r $g $b
    $pdf rectangle $x $y $sw [expr {$CFG(fieldH) + 2}] -filled 1

    # Rahmen
    lassign $CFG(fieldBorder) lr lg lb
    $pdf setStrokeColor $lr $lg $lb
    $pdf setLineWidth $CFG(lineWidth)
    $pdf rectangle $x $y $sw [expr {$CFG(fieldH) + 2}]

    # Text
    $pdf setFont $CFG(fontSizeSection) $CFG(fontFamilyBold)
    lassign $CFG(labelColor) tr tg tb
    $pdf setFillColor $tr $tg $tb
    set textY [expr {$y + $CFG(fieldH) - 2}]
    $pdf text $title -x [expr {$x + 4}] -y $textY

    $pdf setFillColor 0 0 0
    $pdf setStrokeColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y [expr {$CFG(fieldH) + 2 + $CFG(sectionGap)}]
}

# -- labelField ----------------------------------------------

proc ::pdf4tcllib::form::labelField {pdf ctx yVar label ftype args} {
    # Zeichnet Label + Formularfeld nebeneinander und
    # aktualisiert yVar um eine Zeilenhoehe.
    #
    # label  - Beschriftungstext
    # ftype  - Feldtyp: text password checkbox combobox listbox
    #          radiobutton pushbutton signature
    # args   - Optionen weitergeleitet an addForm (z.B. -id -init -options)
    #          Zusaetzlich: -labelw (Label-Breite, Standard aus CFG)
    #                       -fieldw (Feld-Breite, Standard: Rest der Textbreite)
    #                       -fieldh (Feld-Hoehe, Standard aus CFG)
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

    # Label
    $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamily)
    lassign $CFG(labelColor) lr lg lb
    $pdf setFillColor $lr $lg $lb
    set textY [expr {$y + $fieldH - 2}]
    $pdf text $label -x $x -y $textY

    # Feld
    $pdf setFont $CFG(fontSize) $CFG(fontFamily)
    set fx [expr {$x + $labelW + $CFG(labelGap)}]
    $pdf addForm $ftype $fx $y $fieldW $fieldH {*}$passArgs

    $pdf setFillColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y [expr {$fieldH + $CFG(rowGap)}]
}

# -- row -----------------------------------------------------

proc ::pdf4tcllib::form::row {pdf ctx yVar fields} {
    # Zeichnet mehrere Label+Feld-Paare nebeneinander in einer Zeile.
    #
    # fields ist eine Liste von Dicts mit:
    #   label   - Beschriftung
    #   type    - Feldtyp (text checkbox combobox ...)
    #   width   - Gesamtbreite (Label + Feld)
    #   id      - Feld-ID (optional)
    #   init    - Anfangswert (optional)
    #   options - Options-Liste fuer addForm (optional)
    #   labelw  - Label-Breite (optional, Standard aus CFG)
    #   fieldh  - Feld-Hoehe (optional, Standard aus CFG)
    #
    # Beispiel:
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
        set label   [dict getdef $fdef label   ""]
        set ftype   [dict getdef $fdef type    text]
        set totalW  [dict getdef $fdef width   100]
        set labelW  [dict getdef $fdef labelw  $CFG(labelW)]
        set fieldH  [dict getdef $fdef fieldh  $CFG(fieldH)]
        set gap     [dict getdef $fdef gap     $CFG(labelGap)]

        if {$fieldH > $maxH} { set maxH $fieldH }

        # addForm-Optionen zusammenbauen
        set addArgs {}
        if {[dict exists $fdef id]}      { lappend addArgs -id      [dict get $fdef id] }
        if {[dict exists $fdef init]}    { lappend addArgs -init    [dict get $fdef init] }
        if {[dict exists $fdef options]} { lappend addArgs -options [dict get $fdef options] }
        if {[dict exists $fdef readonly]} { lappend addArgs -readonly [dict get $fdef readonly] }
        if {[dict exists $fdef multiline]} { lappend addArgs -multiline [dict get $fdef multiline] }

        set fieldW [expr {$totalW - $labelW - $gap}]

        # Label
        if {$label ne ""} {
            $pdf setFont $CFG(fontSizeLabel) $CFG(fontFamily)
            lassign $CFG(labelColor) lr lg lb
            $pdf setFillColor $lr $lg $lb
            set textY [expr {$y + $fieldH - 2}]
            $pdf text $label -x $x -y $textY
        }

        # Feld
        $pdf setFont $CFG(fontSize) $CFG(fontFamily)
        set fx [expr {$x + $labelW + $gap}]
        $pdf addForm $ftype $fx $y $fieldW $fieldH {*}$addArgs

        set x [expr {$x + $totalW + $CFG(labelGap)}]
    }

    $pdf setFillColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y [expr {$maxH + $CFG(rowGap)}]
}

# -- separator -----------------------------------------------

proc ::pdf4tcllib::form::separator {pdf ctx yVar {gap 4}} {
    # Zeichnet eine horizontale Trennlinie und aktualisiert y.
    upvar 1 $yVar y
    variable CFG

    set x  [dict get $ctx SX]
    set sw [dict get $ctx SW]

    lassign $CFG(lineColor) r g b
    $pdf setStrokeColor $r $g $b
    $pdf setLineWidth $CFG(lineWidth)
    $pdf line $x $y [expr {$x + $sw}] $y
    $pdf setStrokeColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y $gap
}

# -- orderTable ----------------------------------------------

proc ::pdf4tcllib::form::orderTable {pdf ctx yVar headers colWidths \
                                      {data {}} args} {
    # Zeichnet eine Bestelltabelle mit Header-Zeile und Datenzeilen.
    # Leere Zeilen werden am Ende aufgefuellt wenn -emptyRows gesetzt.
    #
    # headers    - Liste der Spaltenheader
    # colWidths  - Liste der Spaltenbreiten in pt (Summe <= SW)
    # data       - Liste von Zeilen (jede Zeile = Liste von Zellwerten)
    # args:
    #   -emptyRows N   Anzahl zusaetzlicher Leerzeilen (Standard: 0)
    #   -rowh      N   Zeilenhoehe (Standard: aus CFG)
    #   -headerBg  {r g b}  Header-Hintergrundfarbe
    upvar 1 $yVar y
    variable CFG

    # Optionen
    set emptyRows 0
    set rowH $CFG(fieldH)
    set headerBg {0.20 0.30 0.50}
    foreach {k v} $args {
        switch -- $k {
            -emptyRows { set emptyRows $v }
            -rowh      { set rowH $v }
            -headerBg  { set headerBg $v }
        }
    }

    set x  [dict get $ctx SX]

    # Header-Zeile
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
        $pdf text $header -x [expr {$cx + 3}] -y $textY
        set cx [expr {$cx + $cw}]
    }

    $pdf setFillColor 0 0 0
    lassign $CFG(fieldBorder) fr fg fb
    $pdf setStrokeColor $fr $fg $fb
    $pdf setLineWidth $CFG(lineWidth)
    $pdf rectangle $x $y $totalW [expr {$rowH + 2}]

    ::pdf4tcllib::page::_advance $ctx y [expr {$rowH + 2}]

    # Datenzeilen
    set rowIdx 0
    foreach row $data {
        # Zebra-Streifen
        if {$rowIdx % 2 == 1} {
            $pdf setFillColor 0.95 0.95 0.95
            $pdf rectangle $x $y $totalW $rowH -filled 1
            $pdf setFillColor 0 0 0
        }

        $pdf setFont $CFG(fontSize) $CFG(fontFamily)
        set cx $x
        foreach cell $row cw $colWidths {
            if {$cw eq ""} continue
            if {$cell ne ""} {
                set textY [expr {$y + $rowH - 2}]
                $pdf text [string range $cell 0 40] \
                    -x [expr {$cx + 3}] -y $textY
            }
            set cx [expr {$cx + $cw}]
        }

        $pdf setStrokeColor $fr $fg $fb
        $pdf rectangle $x $y $totalW $rowH
        ::pdf4tcllib::page::_advance $ctx y $rowH
        incr rowIdx
    }

    # Leerzeilen
    for {set i 0} {$i < $emptyRows} {incr i} {
        if {$rowIdx % 2 == 1} {
            $pdf setFillColor 0.95 0.95 0.95
            $pdf rectangle $x $y $totalW $rowH -filled 1
            $pdf setFillColor 0 0 0
        }
        $pdf setStrokeColor $fr $fg $fb
        $pdf rectangle $x $y $totalW $rowH
        ::pdf4tcllib::page::_advance $ctx y $rowH
        incr rowIdx
    }

    $pdf setStrokeColor 0 0 0

    ::pdf4tcllib::page::_advance $ctx y $CFG(rowGap)
}

# -- sumLine -------------------------------------------------

proc ::pdf4tcllib::form::sumLine {pdf ctx yVar colWidths label value} {
    # Zeichnet eine Summenzeile am Ende einer Bestelltabelle.
    # label und value werden rechtbuendig in den letzten zwei Spalten gesetzt.
    upvar 1 $yVar y
    variable CFG

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
    $pdf text $label -x $labelX -y $textY -align right

    # Wert
    $pdf setFont $CFG(fontSize) $CFG(fontFamily)
    set valX [expr {$x + $totalW - 4}]
    $pdf text $value -x $valX -y $textY -align right

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
