"""Convertit le dossier Markdown en .docx à la charte IBAM.

Usage : python md2docx.py <logos> <sortie.docx> <source.md> [titre page de garde]
Sous-ensemble Markdown géré : titres #/##/###, paragraphes, listes « - » et
« 1. », tableaux « | », blocs ```code```, images ![alt](fichier), citations
« > », séparateurs « --- ». Dans le texte : **gras**, `code`, *italique*,
[texte](url).
"""
import os
import re
import sys

LOGOS, OUT, SRC = sys.argv[1], sys.argv[2], sys.argv[3]
TITRE = sys.argv[4] if len(sys.argv) > 4 else "Dossier d'architecture"
RACINE = os.path.dirname(os.path.abspath(SRC))
PIED = "RÉSULTATS-BF — Groupe 6 — " + TITRE + " — page "
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "helpers_docx.py"), encoding="utf-8").read())

# Portrait : un dossier se lit en portrait, pas en paysage comme les points
sec.orientation = 0
sec.page_width, sec.page_height = Cm(21), Cm(29.7)
sec.left_margin = sec.right_margin = Cm(2)
sec.top_margin = sec.bottom_margin = Cm(1.8)
doc.styles["Normal"].font.size = Pt(10.5)
LARGEUR = 17.0


def italique_et_liens(p, texte):
    """Ajoute le texte avec **gras**, `code`, *italique* et [lien](url)."""
    for part in re.split(r"(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*|\[[^\]]+\]\([^)]+\))", texte):
        if not part:
            continue
        if part.startswith("**"):
            p.add_run(part[2:-2]).bold = True
        elif part.startswith("`"):
            r = p.add_run(part[1:-1]); r.font.name = "Consolas"; r.font.size = Pt(9.5)
            r.font.color.rgb = RGBColor(0x8B, 0x1A, 0x1A)
        elif part.startswith("*"):
            p.add_run(part[1:-1]).italic = True
        elif part.startswith("["):
            m = re.match(r"\[([^\]]+)\]\(([^)]+)\)", part)
            r = p.add_run(m.group(1)); r.font.color.rgb = BLEU; r.underline = True
        else:
            p.add_run(part)


def bloc_code(lignes):
    t = doc.add_table(rows=1, cols=1); t.alignment = WD_TABLE_ALIGNMENT.CENTER
    c = t.cell(0, 0); c.width = Cm(LARGEUR); shade(c, "F4F4F4")
    p = c.paragraphs[0]; p.paragraph_format.space_after = Pt(0)
    for i, l in enumerate(lignes):
        r = p.add_run(l.rstrip()); r.font.name = "Consolas"; r.font.size = Pt(8.5)
        if i < len(lignes) - 1:
            r.add_break()
    doc.add_paragraph().paragraph_format.space_after = Pt(3)


def tableau(lignes):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lignes]
    rows = [r for i, r in enumerate(rows) if not (i == 1 and set("".join(r)) <= set("-: "))]
    n = max(len(r) for r in rows)
    rows = [r + [""] * (n - len(r)) for r in rows]
    t = doc.add_table(rows=len(rows), cols=n)
    t.style = "Table Grid"; t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, row in enumerate(rows):
        for j, val in enumerate(row):
            cell = t.cell(i, j); cell.width = Cm(LARGEUR / n)
            p = cell.paragraphs[0]; p.paragraph_format.space_after = Pt(0)
            if i == 0:
                shade(cell, "1F4E79")
                for part in re.split(r"(\*\*[^*]+\*\*|`[^`]+`)", val):
                    if not part:
                        continue
                    txt = part.strip("*`") if part.startswith(("*", "`")) else part
                    r = p.add_run(txt); r.bold = True; r.font.size = Pt(8.5)
                    r.font.color.rgb = RGBColor(255, 255, 255)
            else:
                if i % 2 == 0:
                    shade(cell, "EEF3F8")
                italique_et_liens(p, val)
                for r in p.runs:
                    if r.font.size is None:
                        r.font.size = Pt(8.5)
    trPr = t.rows[0]._tr.get_or_add_trPr(); th = OxmlElement("w:tblHeader"); th.set(qn("w:val"), "true"); trPr.append(th)
    doc.add_paragraph().paragraph_format.space_after = Pt(3)


lignes = open(SRC, encoding="utf-8").read().split("\n")
i, premier_titre = 0, True
while i < len(lignes):
    l = lignes[i]

    if l.startswith("```"):
        j = i + 1
        while j < len(lignes) and not lignes[j].startswith("```"):
            j += 1
        bloc_code(lignes[i + 1:j]); i = j + 1; continue

    if l.startswith("|") and i + 1 < len(lignes) and set(lignes[i + 1].strip().strip("|")) <= set("-: |"):
        j = i
        while j < len(lignes) and lignes[j].startswith("|"):
            j += 1
        tableau(lignes[i:j]); i = j; continue

    m = re.match(r"!\[([^\]]*)\]\(([^)]+)\)", l.strip())
    if m:
        chemin = os.path.join(RACINE, m.group(2))
        if os.path.exists(chemin):
            p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.add_run().add_picture(chemin, width=Cm(LARGEUR))
        i += 1; continue

    if l.strip() in ("---", "***"):
        i += 1; continue

    if l.startswith("#"):
        niveau = len(l) - len(l.lstrip("#"))
        texte = l.lstrip("# ").strip()
        if premier_titre and niveau == 1:
            # Page de garde
            for t_, sz in (("Université Joseph KI-ZERBO", 15), ("Institut Burkinabè des Arts et Métiers (IBAM)", 12)):
                p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                p.paragraph_format.space_after = Pt(0)
                r = p.add_run(t_); r.bold = True; r.font.size = Pt(sz)
            lt = doc.add_table(rows=1, cols=2); lt.alignment = WD_TABLE_ALIGNMENT.CENTER
            for k, (img, al) in enumerate(((f"{LOGOS}/image1.png", WD_ALIGN_PARAGRAPH.RIGHT),
                                           (f"{LOGOS}/image2.png", WD_ALIGN_PARAGRAPH.LEFT))):
                c = lt.cell(0, k); c.width = Cm(6); pp = c.paragraphs[0]; pp.alignment = al
                pp.add_run().add_picture(img, height=Cm(2.4))
            p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_before = Pt(10)
            r = p.add_run(texte); r.bold = True; r.font.size = Pt(20)
            r.font.color.rgb = BLEU; r.font.name = "Times New Roman"
            premier_titre = False
        else:
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(13 if niveau <= 2 else 9)
            p.paragraph_format.space_after = Pt(4)
            p.paragraph_format.keep_with_next = True
            r = p.add_run(texte); r.bold = True
            r.font.size = Pt(15 if niveau == 1 else (12.5 if niveau == 2 else 11))
            r.font.color.rgb = BLEU
        i += 1; continue

    if l.startswith(">"):
        bloc = [l.lstrip("> ").strip()]
        while i + 1 < len(lignes) and lignes[i + 1].startswith(">"):
            i += 1; bloc.append(lignes[i].lstrip("> ").strip())
        p = doc.add_paragraph(); p.paragraph_format.left_indent = Cm(0.6)
        italique_et_liens(p, " ".join(bloc))
        for r in p.runs:
            r.italic = True
            if r.font.color.rgb is None:
                r.font.color.rgb = RGBColor(0x55, 0x55, 0x55)
        i += 1; continue

    m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)", l)
    if m:
        style = "List Bullet" if m.group(2) in "-*" else "List Number"
        bloc = [m.group(3)]
        # Lignes de continuation : indentées, sans puce ni autre marqueur
        while (i + 1 < len(lignes) and lignes[i + 1].startswith(("  ", "	"))
               and lignes[i + 1].strip()
               and not re.match(r"^\s*([-*]|\d+\.)\s", lignes[i + 1])
               and not lignes[i + 1].lstrip().startswith(("|", "```", ">", "#"))):
            i += 1; bloc.append(lignes[i].strip())
        p = doc.add_paragraph(style=style)
        p.paragraph_format.space_after = Pt(2)
        if m.group(1):
            p.paragraph_format.left_indent = Cm(1.5)
        italique_et_liens(p, " ".join(bloc))
        i += 1; continue

    if l.strip():
        bloc = [l.strip()]
        while i + 1 < len(lignes) and lignes[i + 1].strip() and not re.match(r"^(#|\||>|```|\s*[-*]\s|\s*\d+\.\s|!\[)", lignes[i + 1]):
            i += 1; bloc.append(lignes[i].strip())
        p = doc.add_paragraph(); p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        italique_et_liens(p, " ".join(bloc))
    i += 1

doc.save(OUT)
print("ok", OUT)
