# test_fonts.tcl -- Tests fuer pdf4tcllib::fonts
package require tcltest
namespace import ::tcltest::*

# TTF fonts only available when DejaVu is installed
testConstraint ttfAvailable [pdf4tcllib::fonts::hasTtf]

# ============================================================
# Defaults (vor init)
# ============================================================

test fonts-default-sans "Default fontSans = Helvetica" -body {
    pdf4tcllib::fonts::fontSans
} -result "Helvetica"

test fonts-default-bold "Default fontSansBold = Helvetica-Bold" -body {
    pdf4tcllib::fonts::fontSansBold
} -result "Helvetica-Bold"

test fonts-default-mono "Default fontMono = Courier" -body {
    pdf4tcllib::fonts::fontMono
} -result "Courier"

test fonts-default-ttf "hasTtf = 0 ohne init" -body {
    pdf4tcllib::fonts::hasTtf
} -result 0

# ============================================================
# widthFactor
# ============================================================

test fonts-wf-helvetica "widthFactor Helvetica = 0.58" -body {
    pdf4tcllib::fonts::widthFactor Helvetica
} -result 0.58

test fonts-wf-helv-bold "widthFactor Helvetica-Bold = 0.64" -body {
    pdf4tcllib::fonts::widthFactor Helvetica-Bold
} -result 0.64

test fonts-wf-courier "widthFactor Courier = 0.60" -body {
    pdf4tcllib::fonts::widthFactor Courier
} -result 0.60

test fonts-wf-unknown "widthFactor unbekannter Font = 0.58 (Fallback)" -body {
    pdf4tcllib::fonts::widthFactor "NichtExistent"
} -result 0.52

# ============================================================
# isMonospace
# ============================================================

test fonts-mono-courier "Courier ist Monospace" -body {
    pdf4tcllib::fonts::isMonospace Courier
} -result 1

test fonts-mono-helv "Helvetica ist nicht Monospace" -body {
    pdf4tcllib::fonts::isMonospace Helvetica
} -result 0

test fonts-mono-helv-bold "Helvetica-Bold ist nicht Monospace" -body {
    pdf4tcllib::fonts::isMonospace Helvetica-Bold
} -result 0

# ============================================================
# _buildSubset
# ============================================================

test fonts-subset-basic "Subset enthaelt Latin-1 Basisbereich" -body {
    set sub [pdf4tcllib::fonts::_buildSubset]
    # Muss mindestens 32..126 (druckbares ASCII) enthalten
    set has_A [expr {65 in $sub}]
    set has_z [expr {122 in $sub}]
    set has_0 [expr {48 in $sub}]
    list $has_A $has_z $has_0
} -result {1 1 1}

test fonts-subset-euro "Subset enthaelt Euro-Zeichen (U+20AC)" -constraints {ttfAvailable} -body {
    set sub [pdf4tcllib::fonts::_buildSubset]
    expr {0x20AC in $sub}
} -result 1

test fonts-subset-arrow "Subset enthaelt Pfeil rechts (U+2192)" -constraints {ttfAvailable} -body {
    set sub [pdf4tcllib::fonts::_buildSubset]
    expr {0x2192 in $sub}
} -result 1

test fonts-subset-checkmark "Subset enthaelt Haekchen (U+2713)" -constraints {ttfAvailable} -body {
    set sub [pdf4tcllib::fonts::_buildSubset]
    expr {0x2713 in $sub}
} -result 1

# ============================================================
# _buildSearchPaths
# ============================================================

test fonts-searchpaths "Suchpfade sind nicht leer" -body {
    set paths [pdf4tcllib::fonts::_buildSearchPaths ""]
    expr {[llength $paths] > 0}
} -result 1

cleanupTests
