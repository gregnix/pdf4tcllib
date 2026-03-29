#!/usr/bin/env python3
"""pdfanalyze.py -- PyMuPDF-based PDF analysis for pdflab2
Usage: python3 pdfanalyze.py <pdf> <output.json> [password]
Output: JSON with per-page words, images, paths, overlaps, line-hits, margin violations
"""
import sys, json, fitz  # fitz = PyMuPDF

MARGIN_PT = 36   # minimum margin in points (~12.7 mm)

def bbox_overlap(a, b):
    """True if two (x0,y0,x1,y1) rects overlap."""
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]

def analyze_page(page):
    pw, ph = page.rect.width, page.rect.height

    # Words: list of (x0,y0,x1,y1,text,block,line,word)
    words = [{"x0": w[0], "y0": w[1], "x1": w[2], "y1": w[3], "text": w[4]}
             for w in page.get_text("words")]

    # Images
    images = [{"xref": img[0], "width": img[2], "height": img[3],
                "cs": img[4], "bpc": img[5]}
              for img in page.get_images(full=True)]

    # Paths (lines, rectangles, curves from content stream)
    paths = []
    for p in page.get_drawings():
        paths.append({
            "type": p.get("type", "?"),
            "rect": list(p["rect"]),
            "color": p.get("color"),
            "fill":  p.get("fill"),
        })

    # Overlapping words (O(n^2), limited to 500 words)
    overlaps = 0
    wlist = words[:500]
    for i in range(len(wlist)):
        for j in range(i+1, len(wlist)):
            a = (wlist[i]["x0"], wlist[i]["y0"], wlist[i]["x1"], wlist[i]["y1"])
            b = (wlist[j]["x0"], wlist[j]["y0"], wlist[j]["x1"], wlist[j]["y1"])
            if bbox_overlap(a, b):
                overlaps += 1

    # Lines through text: horizontal path segments that intersect word bboxes
    line_hits = 0
    for p in paths:
        if p["type"] != "l":  # not a line
            continue
        r = p["rect"]
        # Horizontal if height near 0
        if abs(r[3] - r[1]) > 3:
            continue
        # Extend line rect slightly vertically to test intersection
        lr = (r[0], r[1] - 2, r[2], r[3] + 2)
        for w in words:
            wr = (w["x0"], w["y0"], w["x1"], w["y1"])
            if bbox_overlap(lr, wr):
                line_hits += 1
                break  # count once per line

    # Text-on-graphics overlaps: words that overlap any filled/stroked path
    # Excludes lines (already counted above) and very small paths (dots)
    text_on_graphics = 0
    text_on_graphics_list = []
    MIN_PATH_AREA = 9  # ignore paths smaller than 3x3 pt (dots, hairlines)
    for w in words:
        wr = (w["x0"], w["y0"], w["x1"], w["y1"])
        for p in paths:
            r = p["rect"]
            # Skip invisible paths and tiny ones
            area = (r[2] - r[0]) * (r[3] - r[1])
            if area < MIN_PATH_AREA:
                continue
            # Skip unfilled lines (stroke only with no area)
            if p.get("fill") is None and abs(r[3] - r[1]) < 3:
                continue
            if bbox_overlap(wr, (r[0], r[1], r[2], r[3])):
                text_on_graphics += 1
                text_on_graphics_list.append({
                    "word": w["text"],
                    "word_bbox": [w["x0"], w["y0"], w["x1"], w["y1"]],
                    "path_bbox": r,
                })
                break  # count once per word

    # Margin violations
    margin_violations = sum(
        1 for w in words
        if w["x0"] < MARGIN_PT or w["x1"] > pw - MARGIN_PT
        or w["y0"] < MARGIN_PT or w["y1"] > ph - MARGIN_PT
    )

    return {
        "page": page.number + 1,
        "width": pw, "height": ph,
        "words":  words[:200],   # cap for JSON size
        "images": images,
        "paths":  paths[:200],
        "overlaps": overlaps,
        "line_hits": line_hits,
        "text_on_graphics": text_on_graphics,
        "text_on_graphics_list": text_on_graphics_list[:50],
        "margin_violations": margin_violations,
    }

def main():
    if len(sys.argv) < 3:
        print("Usage: pdfanalyze.py <pdf> <out.json> [password]", file=sys.stderr)
        sys.exit(1)
    pdfpath  = sys.argv[1]
    outpath  = sys.argv[2]
    password = sys.argv[3] if len(sys.argv) > 3 else ""

    doc = fitz.open(pdfpath)
    if doc.is_encrypted:
        if not doc.authenticate(password):
            print("ERROR: Wrong password", file=sys.stderr)
            sys.exit(1)

    # Document info
    meta = doc.metadata
    info = {k: (meta.get(k) or "") for k in
            ["title","author","subject","creator","producer","creationDate","modDate"]}
    info["pages"] = doc.page_count
    info["encrypted"] = doc.is_encrypted
    # pdf_version() exists in PyMuPDF >= 1.18.7; older builds use PDFversion()
    # or store it in metadata["format"]. Use a safe fallback chain.
    try:
        ver = doc.pdf_version()          # returns (major, minor) tuple
        info["version"] = f"{ver[0]}.{ver[1]}" if isinstance(ver, tuple) else str(ver)
    except AttributeError:
        try:
            info["version"] = str(doc.PDFversion())
        except AttributeError:
            info["version"] = meta.get("format", "?")

    # Fonts (from first 20 pages to keep it fast)
    seen_fonts = {}
    for pn in range(min(doc.page_count, 20)):
        for f in doc[pn].get_fonts(full=True):
            name = f[3] or f[4] or "?"
            if name not in seen_fonts:
                seen_fonts[name] = {
                    "name": name,
                    "type": f[2],
                    "embedded": f[5] != "",  # f[5] = font file xref
                    "subset": "+" in (f[3] or ""),
                }
    fonts = list(seen_fonts.values())

    # Suspicious elements
    suspicious = []
    for pn in range(doc.page_count):
        page = doc[pn]
        for annot in page.annots():
            if annot.type[1] in ("FileAttachment", "Sound", "Movie", "Widget"):
                suspicious.append(f"Seite {pn+1}: Annotation {annot.type[1]}")
        text = page.get_text()
        if "/JavaScript" in text or "app.launchURL" in text:
            suspicious.append(f"Seite {pn+1}: JavaScript-Hinweis im Text")

    # Per-page analysis
    pages = [analyze_page(doc[pn]) for pn in range(doc.page_count)]

    result = {
        "info": info,
        "fonts": fonts,
        "suspicious": suspicious,
        "pages": pages,
    }

    with open(outpath, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"OK: {doc.page_count} pages analyzed -> {outpath}")

if __name__ == "__main__":
    main()
