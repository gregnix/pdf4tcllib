# pdf4tcllib Makefile
#
# Die Module liegen unter lib/<name>-<version>.tm -- der Dateiname traegt
# die Version, weil Tcl sie von dort liest.
#
# Wer pdf4tcllib einbettet (mdstack, mdhelp4), kopiert die gebrauchten
# Module direkt aus lib/ in sein eigenes vendors/tm/. Siehe
# nogit/docs/de/handbuch-github-pdf4tcllib.md.
#
#   make test    - Testsuite (tests/run_all.tcl)
#   make conform - erzeugte PDFs gegen veraPDF halten
#   make geometry- gezeichnete Geometrie ausserhalb der Seite finden
#   make clean   - entfernt generierte Ausgaben

MODULES := $(notdir $(wildcard lib/*.tm))

TCLSH   ?= tclsh
SH      ?= sh

.PHONY: all test conform geometry clean help

help:
	@echo "Targets:"
	@echo "  make test    # Testsuite (tests/run_all.tcl)"
	@echo "  make conform # veraPDF ueber die erzeugten PDFs"
	@echo "  make geometry# gezeichnete Geometrie ausserhalb der Seite"
	@echo "  make clean   # entfernt generierte Test-Ausgaben (out/)"
	@echo "  Module: $(MODULES)"

all: test

test:
	$(TCLSH) tests/run_all.tcl

# Prueft nur Dateien, die selbst einen Anspruch erheben. Ohne veraPDF
# beendet sich das Skript mit Hinweis und rc=0.
conform:
	$(SH) tools/check-conformance.sh

# Was layout-check nicht sieht: Gezeichnetes. Drei Demos liefen darum
# monatelang ueber den Blattrand, ohne dass eine Pruefung anschlug.
# Beide Verzeichnisse muessen sauber sein. Seit der Pruefer
# cm-Transformationen folgt, sind die frueheren sechs "Fehlalarme" in
# examples/advanced erledigt: vier waren welche, zwei waren Fehler.
geometry:
	$(TCLSH) tools/geometry-check.tcl examples/basic/pdf
	$(TCLSH) tools/geometry-check.tcl examples/advanced/pdf

clean:
	rm -rf out/*.pdf out/*.html 2>/dev/null || true
