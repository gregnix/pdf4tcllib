#!/bin/sh
# check-conformance.sh -- erzeugte PDFs gegen veraPDF halten.
#
#   sh tools/check-conformance.sh [verzeichnis ...]
#
# Prueft NUR Dateien, die selbst einen Anspruch erheben. Eine Datei ohne
# pdfaid oder pdfuaid im XMP behauptet nichts und kann nichts brechen --
# sie als "durchgefallen" zu fuehren waere falsch.
#
# Ohne veraPDF im PATH beendet sich das Skript mit einem Hinweis und
# rc=0: fehlendes Werkzeug ist kein Fehlschlag der Bibliothek.
#
# Gemessen 2026-08-18: von 82 erzeugten Beispiel-PDFs erheben vier einen
# Anspruch, und alle vier halten ihn.

set -e

if ! command -v verapdf >/dev/null 2>&1; then
    echo "veraPDF nicht im PATH -- uebersprungen."
    echo "  https://verapdf.org/software/  (greenfield-Build genuegt)"
    exit 0
fi
if ! command -v qpdf >/dev/null 2>&1; then
    echo "qpdf nicht im PATH -- der Anspruch laesst sich nicht lesen."
    exit 0
fi

DIRS="$*"
if [ -z "$DIRS" ]; then
    DIRS="examples/basic/pdf examples/advanced/pdf tests/out"
fi

# Eine Zwischendatei fuer das entpackte PDF, aufgeraeumt beim Ende.
tmpxmp=$(mktemp)
trap 'rm -f "$tmpxmp"' EXIT INT TERM

geprueft=0
bestanden=0
gefallen=0
ohne=0

for dir in $DIRS; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.pdf; do
        [ -f "$f" ] || continue

        # Was behauptet die Datei? Der Anspruch steht im XMP.
        #
        # Einmal entpacken, in eine Datei, dann daraus lesen. NICHT in
        # eine Shell-Variable: ein PDF enthaelt NULL-Bytes in seinen
        # Streams, und die Kommandoersetzung wirft sie mit einer Warnung
        # je Datei weg. Und nicht dreimal qpdf je Datei.
        qpdf --qdf --object-streams=disable --stream-data=uncompress \
                "$f" - > "$tmpxmp" 2>/dev/null || true
        teil=$(grep -a -o 'pdfaid:part>[0-9]' "$tmpxmp" | head -1 \
                | sed 's/.*>//')
        stufe=$(grep -a -o 'pdfaid:conformance>[ABU]' "$tmpxmp" | head -1 \
                | sed 's/.*>//' | tr 'ABU' 'abu')
        ua=$(grep -a -c 'pdfuaid:part' "$tmpxmp" || true)

        profile=""
        [ -n "$teil" ] && [ -n "$stufe" ] && profile="${teil}${stufe}"
        [ "$ua" != "0" ] && profile="${profile:+$profile }ua1"

        if [ -z "$profile" ]; then
            ohne=$((ohne + 1))
            continue
        fi

        for p in $profile; do
            geprueft=$((geprueft + 1))
            r=$(verapdf -f "$p" --format text "$f" 2>/dev/null | head -1 \
                    | awk '{print $1}')
            case "$r" in
                PASS)
                    bestanden=$((bestanden + 1))
                    printf "  ok    %-30s %s\n" "$(basename "$f")" "$p"
                    ;;
                *)
                    gefallen=$((gefallen + 1))
                    printf "  FAIL  %-30s %s\n" "$(basename "$f")" "$p"
                    # Die Klauseln nennen, sonst muss man von Hand suchen.
                    verapdf -f "$p" "$f" 2>/dev/null \
                        | grep -oE 'clause="[^"]*"' | sort -u \
                        | sed 's/^/          /' | head -5
                    ;;
            esac
        done
    done
done

echo ""
if [ $((geprueft + ohne)) -eq 0 ]; then
    echo "  Keine PDF-Datei gefunden in: $DIRS"
    echo "  Die Beispiele schreiben nach examples/basic/pdf und"
    echo "  examples/advanced/pdf -- ohne Argument werden die genommen."
    exit 0
fi
echo "  $geprueft mit Anspruch geprueft: $bestanden bestanden, $gefallen durchgefallen"
echo "  $ohne ohne Anspruch (nicht geprueft)"

[ "$gefallen" -eq 0 ] || exit 1
