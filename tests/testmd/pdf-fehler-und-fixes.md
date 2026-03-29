# PDF-Erzeugung: Bekannte Probleme und Fixes

Stand: 2026-03-07
Betrifft: mdpdf-0.2.tm, pdf4tcllib-0.1.tm, pdf4tcl 0.9.4


## 1. Spacing zu eng (gefixt in mdpdf-0.2.tm)

### Symptom

Headings kleben am vorherigen Absatz. Code-Bloecke haben
keinen Abstand zum Text davor und danach. Das Dokument
wirkt gedraengt und schwer lesbar.

### Ursache

Vier Spacing-Werte in mdpdf-0.2.tm waren zu klein oder fehlten.

### Fix

| Element | Vorher | Nachher | Zeile |
|---|---|---|---|
| Space vor Heading | `hFontSize * 0.5` (~7pt) | `hFontSize * 1.2` (~18pt) | 311 |
| Space nach Heading | `hFontSize * 1.3` (~19pt) | `hFontSize * 1.6` (~24pt) | 328 |
| Space vor Code-Block | 0pt (fehlte) | `lineH * 0.4` (~6pt) | 362 (neu) |
| Space nach Code-Block | 0pt (fehlte) | `lineH * 0.4` (~6pt) | 412 (neu) |

### Status

Gefixt. mdpdf-0.2.tm in mdhelp4/vendors/tm/ und
pdf4tcllib/vendors/tm/ ersetzen.


## 2. Baumstruktur-Zeichen erzeugen Linien im PDF

### Symptom

Vertikale und horizontale Linien laufen durch Code-Bloecke
die Verzeichnisbaeume darstellen. Die Pipe-Zeichen `|` und
Striche `---` werden von manchen PDF-Renderern als
Tabellenstrukturen interpretiert.

### Ursache

Unicode Box-Drawing-Zeichen (U+251C, U+2514, U+2502) oder
ASCII `|--` in Code-Bloecken werden beim Markdown-zu-PDF
Rendering als Layout-Elemente statt als Text interpretiert.

### Fix

ASCII-Baumzeichen verwenden die eindeutig als Text erkannt werden:

```
FALSCH (Unicode Box-Drawing):
+-- app/
|   +-- main.tcl

FALSCH (Pipe + Dashes):
|-- app/
|   |-- main.tcl

RICHTIG (Plus + Dashes):
+-- app/
|   +-- main.tcl
```

In Markdown-Dokumenten die als PDF exportiert werden:
`+--` statt `|--` und `+--` statt Unicode-Baumzeichen.

### Status

Gefixt im regelbuch-0_8.md. Alle anderen Dokumente pruefen.


## 3. Bold-Text ohne Leerzeichen danach

### Symptom

Nach fett markiertem Text fehlt der Abstand zum naechsten Wort.
Beispiel: "**Regel:**Reine Tcl-Packages" statt
"**Regel:** Reine Tcl-Packages".

### Ursache

Im Markdown fehlt ein Leerzeichen nach der schliessenden
Bold-Markierung `**`:

```markdown
FALSCH:
**Regel:**Reine Tcl-Packages immer bevorzugen.

RICHTIG:
**Regel:** Reine Tcl-Packages immer bevorzugen.
```

pdf4tcl setzt die Textfragmente direkt hintereinander.
Ein fehlendes Leerzeichen im Markdown wird im PDF zu
ueberlappenden Glyphen.

### Fix

Grep ueber alle .md-Dateien:

```bash
grep -nP '\*\*[^*]+\*\*[a-zA-Z0-9]' *.md
```

Jede Fundstelle: Leerzeichen nach `**` einfuegen.

### Status

Offen. Muss pro Datei geprueft werden.


## 4. Widow/Orphan: Heading als letzte Zeile

### Symptom

Eine Ueberschrift steht als letzte Zeile auf einer Seite,
der zugehoerige Text beginnt auf der naechsten Seite.

### Ursache

mdpdf prueft zwar ob Heading + 1 Zeile Text auf die Seite
passen (`if {$y + $hFontSize * 2.5 > $yBot}`), aber der
Faktor 2.5 ist zu knapp. Mit dem neuen groesseren Spacing
reicht das nicht immer.

### Fix

Faktor erhoehen:

```tcl
;# Vorher:
if {$y + $hFontSize * 2.5 > $yBot} {

;# Nachher (Heading + 2 Zeilen Text):
if {$y + $hFontSize * 3.5 > $yBot} {
```

### Status

**Gefixt 2026-03-07.** mdpdf-0.2.tm Zeile ~310.


## 5. Code-Block-Padding zu schmal

### Symptom

Text in Code-Bloecken sitzt zu dicht am linken Rand des
grauen Hintergrunds (falls Hintergrund gezeichnet wird).

### Ursache

mdpdf zeichnet Code-Text direkt ab `x0` ohne Einrueckung.
Es gibt kein separates Padding fuer Code-Bloecke.

### Vorgeschlagener Fix

```tcl
;# In code_block Rendering:
set codePadding 6   ;# 6pt links und rechts
set codeX0 [expr {$x0 + $codePadding}]
set codeMaxW [expr {$maxW - 2 * $codePadding}]

;# Dann codeX0 statt x0 verwenden:
$pdf text $wline -x $codeX0 -y $y
```

Falls ein Hintergrund-Rechteck gezeichnet wird, muss dieses
um `codePadding` breiter sein als der Text.

### Status

**Gefixt 2026-03-07.** mdpdf-0.2.tm: codeX0, codeMaxW eingeführt.


## 6. Zeilenabstand Fliesstext

### Symptom

Fliesstext wirkt etwas eng. Zeilen stehen zu dicht beieinander.

### Analyse

Aktuell: `lineH = ceil(fontSize * 1.4)` bei fontSize=11 ergibt
lineH=16pt. Das entspricht einem Zeilenabstand von ~1.45.

Die Empfehlung fuer technische Dokumentation ist 1.2-1.3,
aber das bezieht sich auf den Faktor relativ zur Schriftgroesse
inklusive Durchschuss. Der aktuelle Wert ist tatsaechlich gut.

### Status

Kein Fix noetig. Der Wert 1.4 ist angemessen.


## 7. Schriftgroessen-Hierarchie

### Analyse

Aktuelle Werte (bei fontSize=11):

| Element | Groesse | Font |
|---|---|---|
| H1 | 15pt (+4) | Sans Bold |
| H2 | 13pt (+2) | Sans Bold |
| H3 | 12pt (+1) | Sans Bold |
| H4-H6 | 11pt (+0) | Sans Bold |
| Fliesstext | 11pt | Sans |
| Code | 11pt | Mono |

Die Differenz H3 (12pt) zu Fliesstext (11pt) ist nur 1pt --
visuell kaum unterscheidbar. Fuer Dokumente mit tiefer
Heading-Hierarchie (H1-H4) koennte das problematisch sein.

### Vorgeschlagener Fix (optional)

```tcl
;# Groessere Spreizung:
set hDeltas {6 4 2 1 0 0}
;# H1=17pt, H2=15pt, H3=13pt, H4=12pt
```

### Status

**Gefixt 2026-03-07.** mdpdf-0.2.tm: hDeltas auf {6 4 2 1 0 0} gesetzt.


## 8. Tabellen-Rendering

### Bekannte Einschraenkungen

- Spaltenbreiten werden proportional berechnet, nicht am Inhalt
- Sehr lange Zelleninhalte werden abgeschnitten, nicht umbrochen
- Tabellen koennen nicht ueber Seitengrenzen brechen

### Status

Bekannt. Mittlere Prioritaet fuer kuenftige Versionen.


## Zusammenfassung

| # | Problem | Prioritaet | Status |
|---|---|---|---|
| 1 | Spacing zu eng | Hoch | **Gefixt** |
| 2 | Baumzeichen als Linien | Hoch | **Gefixt** (im Markdown) |
| 3 | Bold ohne Leerzeichen | Mittel | **Gefixt** (kein Treffer in allen .md) |
| 4 | Widow/Orphan Headings | Mittel | **Gefixt 2026-03-07** |
| 5 | Code-Block-Padding | Niedrig | **Gefixt 2026-03-07** |
| 6 | Zeilenabstand | Kein Fix | OK |
| 7 | Schriftgroessen-Hierarchie | Niedrig | **Gefixt 2026-03-07** |
| 8 | Tabellen-Seitenumbruch | Mittel | Bekannt |
| 9 | Italic Font-Mismatch | Mittel | **Gefixt 2026-03-07** |


## 9. Italic/BoldItalic: Font-Metriken-Mismatch

### Symptom

pdftotext zeigt "bold withitalic inside" statt "bold with italic inside".
Leerzeichen zwischen Segmenten unterschiedlicher Fonts verschwinden
in der Textextraktion. Visuell im PDF ggf. korrekt, aber:
- Copy/Paste aus dem PDF gibt falschen Text
- Barrierefreiheit (Screen Reader) interpretiert falsch

### Ursache

Normal/Bold nutzten TTF-Fonts (DejaVuSansCondensed).
Italic/BoldItalic nutzten Helvetica-Oblique/BoldOblique (Type1).
Unterschiedliche Font-Metrik-Tabellen: pdftotext berechnet Positionen
falsch beim Uebergang TTF -> Type1 und fuegt kein Leerzeichen ein.

### Fix

pdf4tcllib::fonts::init laedt jetzt optional:
- DejaVuSansCondensed-Oblique.ttf als Pdf4tclSansItalic
- DejaVuSansCondensed-BoldOblique.ttf als Pdf4tclSansBoldItalic

Neue Accessoren: fontSansItalic, fontSansBoldItalic, hasTtfItalic.
mdpdf::_styleToFont nutzt die neuen Accessoren.
_renderStyledLine behandelt alle Stile einheitlich (kein Sonderfall mehr).

Fallback: wenn Oblique-TTF fehlt, weiterhin Helvetica-Oblique.

### Status

**Gefixt 2026-03-07.** pdf4tcllib-0.1.tm + mdpdf-0.2.tm.
