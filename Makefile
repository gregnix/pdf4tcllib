# pdf4tcllib Makefile -- Sync / Test
#
# Die Module liegen an ZWEI Stellen im Repo:
#   lib/<tm>          - die Entwicklungs-Quelle (die Tests laden ./lib)
#   vendors/tm/<tm>   - die assemblierten Kopien, die andere Repos vendorn
#
# `lib/` ist die einzige Quelle der Wahrheit; `vendors/tm/` wird daraus
# erzeugt. Dieses Makefile synct ALLE Module (lib/*.tm) -- der fruehere
# Single-VERSION-Ansatz brach bei jedem Versionsbump.
#
#   make sync    - kopiert jedes neuere lib/<tm> -> vendors/tm/<tm>
#   make check   - prueft, ob alle Kopien identisch sind (Exit 1 bei Drift)
#   make prune   - entfernt Vendor-Kopien ohne Gegenstueck in lib/ (Altversionen)
#   make test    - laeuft die Testsuite (tests/run_all.tcl)

MODULES := $(notdir $(wildcard lib/*.tm))
VENDOR  := $(addprefix vendors/tm/,$(MODULES))

TCLSH   ?= tclsh

.PHONY: all sync check prune test clean help

help:
	@echo "Targets:"
	@echo "  make sync    # lib/*.tm -> vendors/tm/  (haelt die Vendor-Kopien aktuell)"
	@echo "  make check   # verifiziert, dass alle Kopien identisch sind"
	@echo "  make prune   # loescht Vendor-Altversionen ohne lib/-Gegenstueck"
	@echo "  make test    # Testsuite (tests/run_all.tcl)"
	@echo "  make clean   # entfernt generierte Test-Ausgaben (out/)"
	@echo "  Module: $(MODULES)"

all: sync

# Vendor-Kopie nur neu schreiben, wenn die Quelle neuer ist.
vendors/tm/%.tm: lib/%.tm
	@mkdir -p vendors/tm
	cp $< $@
	@echo "synced $< -> $@"

sync: $(VENDOR)

# Drift-Waechter: jede lib/-Quelle muss eine identische Vendor-Kopie haben.
check:
	@fail=0; \
	for m in $(MODULES); do \
	  if [ ! -f vendors/tm/$$m ]; then echo "MISSING: vendors/tm/$$m"; fail=1; \
	  elif ! cmp -s lib/$$m vendors/tm/$$m; then echo "DRIFT: lib/$$m != vendors/tm/$$m"; fail=1; fi; \
	done; \
	if [ $$fail -eq 0 ]; then echo "OK: alle Module synchron"; else echo "-> 'make sync' ausfuehren"; exit 1; fi

# Vendor-Kopien entfernen, zu denen es keine lib/-Quelle mehr gibt (Altversionen).
prune:
	@for v in vendors/tm/*.tm; do \
	  b=$$(basename $$v); \
	  if [ ! -f lib/$$b ]; then echo "prune $$v"; rm -f $$v; fi; \
	done; true

test:
	$(TCLSH) tests/run_all.tcl

clean:
	rm -rf out/*.pdf out/*.html 2>/dev/null || true
