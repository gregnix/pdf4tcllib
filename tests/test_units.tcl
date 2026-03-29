# test_units.tcl -- Tests fuer pdf4tcllib::units
package require tcltest
namespace import ::tcltest::*

# ============================================================
# mm -> pt
# ============================================================

test units-mm-1 "1mm = 2.8346pt" -body {
    format "%.2f" [pdf4tcllib::units::mm 1]
} -result "2.83"

test units-mm-2 "25.4mm = 72pt (1 Zoll)" -body {
    format "%.1f" [pdf4tcllib::units::mm 25.4]
} -result "72.0"

test units-mm-3 "0mm = 0pt" -body {
    pdf4tcllib::units::mm 0
} -result 0.0

test units-mm-4 "A4-Breite 210mm" -body {
    format "%.1f" [pdf4tcllib::units::mm 210]
} -result "595.3"

# ============================================================
# cm -> pt
# ============================================================

test units-cm-1 "2.54cm = 72pt (1 Zoll)" -body {
    format "%.1f" [pdf4tcllib::units::cm 2.54]
} -result "72.0"

test units-cm-2 "1cm = 28.35pt" -body {
    format "%.2f" [pdf4tcllib::units::cm 1]
} -result "28.35"

# ============================================================
# inch -> pt
# ============================================================

test units-inch-1 "1 Zoll = 72pt" -body {
    pdf4tcllib::units::inch 1
} -result 72.0

test units-inch-2 "0.5 Zoll = 36pt" -body {
    pdf4tcllib::units::inch 0.5
} -result 36.0

# ============================================================
# Rueckrechnung pt -> mm/cm/inch
# ============================================================

test units-to_mm-1 "72pt = 25.4mm" -body {
    format "%.1f" [pdf4tcllib::units::to_mm 72]
} -result "25.4"

test units-to_cm-1 "72pt = 2.54cm" -body {
    format "%.2f" [pdf4tcllib::units::to_cm 72]
} -result "2.54"

test units-to_inch-1 "72pt = 1 Zoll" -body {
    format "%.1f" [pdf4tcllib::units::to_inch 72]
} -result "1.0"

# ============================================================
# Roundtrip
# ============================================================

test units-roundtrip-mm "mm -> pt -> mm" -body {
    set pt [pdf4tcllib::units::mm 50]
    format "%.1f" [pdf4tcllib::units::to_mm $pt]
} -result "50.0"

test units-roundtrip-cm "cm -> pt -> cm" -body {
    set pt [pdf4tcllib::units::cm 10]
    format "%.1f" [pdf4tcllib::units::to_cm $pt]
} -result "10.0"

test units-roundtrip-inch "inch -> pt -> inch" -body {
    set pt [pdf4tcllib::units::inch 3.5]
    format "%.1f" [pdf4tcllib::units::to_inch $pt]
} -result "3.5"

cleanupTests
