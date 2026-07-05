# pdf4tcllib Makefile -- Sync / Test
#
# Das Modul liegt an ZWEI Stellen im Repo:
#   lib/<tm>          - die Entwicklungs-Quelle (die Tests laden ./lib)
#   vendors/tm/<tm>   - die assemblierte Kopie, die andere Repos vendorn
#
# `lib/` ist die einzige Quelle der Wahrheit; `vendors/tm/` wird daraus
# erzeugt. Frueher wurden beide von Hand editiert -- das ist genau das
# Sync-Risiko, das dieses Makefile beseitigt:
#
#   make sync    - kopiert lib/<tm> -> vendors/tm/<tm> (nur wenn lib/ neuer)
#   make check   - prueft, ob beide Kopien identisch sind (Exit 1 bei Drift)
#   make test    - laeuft die Testsuite (tests/run_all.tcl)
#
# In CI/vor dem Commit: `make check` faengt vergessene Syncs ab.

MODULE  := pdf4tcllib
VERSION := 0.3
TM      := $(MODULE)-$(VERSION).tm

SRC     := lib/$(TM)
VENDOR  := vendors/tm/$(TM)

TCLSH   ?= tclsh

.PHONY: all sync check test clean help

help:
	@echo "Targets:"
	@echo "  make sync    # $(SRC) -> $(VENDOR) (haelt die Vendor-Kopie aktuell)"
	@echo "  make check   # verifiziert, dass beide Kopien identisch sind"
	@echo "  make test    # Testsuite (tests/run_all.tcl)"
	@echo "  make clean   # entfernt generierte Test-Ausgaben (out/)"

all: sync

# Vendor-Kopie nur neu schreiben, wenn die Quelle neuer ist.
$(VENDOR): $(SRC)
	@mkdir -p $(dir $(VENDOR))
	cp $(SRC) $(VENDOR)
	@echo "synced $(SRC) -> $(VENDOR)"

sync: $(VENDOR)

# Drift-Waechter: beide Kopien muessen byte-identisch sein.
check:
	@if cmp -s $(SRC) $(VENDOR); then \
	  echo "OK: $(SRC) und $(VENDOR) sind synchron"; \
	else \
	  echo "DRIFT: $(SRC) != $(VENDOR) -- 'make sync' ausfuehren"; \
	  exit 1; \
	fi

test:
	$(TCLSH) tests/run_all.tcl

clean:
	rm -rf out/*.pdf out/*.html 2>/dev/null || true
