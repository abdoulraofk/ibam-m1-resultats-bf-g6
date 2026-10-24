"""Schéma d'architecture RÉSULTATS-BF pour le dossier (PNG 300 dpi)."""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

OUT = sys.argv[1]
BLEU, BLEU_CLAIR, GRIS, VERT, ORANGE = "#1F4E79", "#DCE6F2", "#7F7F7F", "#E2F0D9", "#FFF2CC"

fig, ax = plt.subplots(figsize=(11.5, 6.6), dpi=300)
ax.set_xlim(0, 115); ax.set_ylim(0, 66); ax.axis("off")


def boite(x, y, w, h, titre, sous="", fond=BLEU_CLAIR, bord=BLEU, pointille=False):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.4,rounding_size=1.2",
                                fc=fond, ec=bord, lw=1.6, ls="--" if pointille else "-"))
    ax.text(x + w / 2, y + h / 2 + (1.4 if sous else 0), titre, ha="center", va="center",
            fontsize=10, fontweight="bold", color="#1A1A1A")
    if sous:
        ax.text(x + w / 2, y + h / 2 - 1.9, sous, ha="center", va="center", fontsize=7.6, color="#333333")


def fleche(x1, y1, x2, y2, texte="", couleur=BLEU, style="-|>", ls="-", dx=0, dy=1.2, taille=7.4):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style, mutation_scale=13,
                                 color=couleur, lw=1.4, ls=ls))
    if texte:
        ax.text((x1 + x2) / 2 + dx, (y1 + y2) / 2 + dy, texte, ha="center", va="bottom",
                fontsize=taille, color=couleur)


# Cadre du réseau privé
ax.add_patch(FancyBboxPatch((17, 2), 96, 61, boxstyle="round,pad=0.3,rounding_size=2",
                            fc="#FAFBFD", ec=GRIS, lw=1, ls=":"))
ax.text(19, 61, "Réseau privé VirtualBox 192.168.61.0/24 (groupe 6) — trafic interne uniquement (R8)",
        fontsize=8, color=GRIS, va="center")

# Hôte
boite(0.5, 27, 13, 12, "Hôte", "navigateur, ab,\nscripts d'essai", fond="#F2F2F2", bord=GRIS)

# Répartiteurs
boite(24, 38, 17, 11, "lb1  .11", "HAProxy — MASTER\nkeepalived prio 150")
boite(24, 18, 17, 11, "lb2  .12", "HAProxy — BACKUP\nkeepalived prio 100", fond=ORANGE, pointille=True)
ax.add_patch(FancyBboxPatch((25.5, 31.2), 14, 4.6, boxstyle="round,pad=0.3", fc="white", ec=BLEU, lw=1.2))
ax.text(32.5, 33.5, "IP virtuelle .10", ha="center", va="center", fontsize=7.6, fontweight="bold", color=BLEU)
ax.text(32.5, 15.6, "E1 (EXT=e1)", ha="center", fontsize=7.4, color="#9C6500")

# Applications
for i, y in enumerate((47, 36, 25)):
    boite(51, y, 19, 8.4, f"app{i + 1}  .2{i + 1}", "Flask + gunicorn, :8000\nsans état")
ax.text(60.5, 21.6, "… appN  (NB_APP = 2 à 9)", ha="center", fontsize=7.6, color="#333333", style="italic")

# Bases
boite(80, 42, 17, 11, "bdd1  .31", "PostgreSQL 16\nprimaire")
boite(80, 20, 17, 11, "bdd2  .32", "réplique en flux\npromouvable", fond=VERT)

# Supervision
boite(99, 3.5, 13, 10.5, "obs  .41", "Prometheus\nGrafana :3000", fond=ORANGE, pointille=True)
ax.text(105.5, 15.4, "E2 (EXT=e2)", ha="center", fontsize=7.4, color="#9C6500")

# Flux
fleche(13.5, 36, 24, 43, "localhost:8080", dx=-4.5, dy=1.6)
fleche(13.5, 31, 25.2, 33.4, "", ls="--")
for y in (51, 40, 29):
    fleche(41.3, 43.5, 51, y)
ax.text(44.5, 53.5, "roundrobin\nsonde GET /sante\n1 s, 2 échecs", ha="center", fontsize=7.2, color=BLEU)
fleche(41.3, 23.5, 51, 29, ls="--")
for y in (51, 40, 29):
    fleche(70.3, y, 80, 47.5)
ax.text(77.5, 57, "BDD_HOTE relu\nà chaque requête", ha="center", fontsize=7.2, color=BLEU)
fleche(88.5, 41.6, 88.5, 31.4, "réplication en flux", couleur="#2E7D32", dx=7.6, dy=-1)
fleche(70.3, 29, 80, 25.5, "après\nbascule.sh", couleur="#2E7D32", ls="--", dx=-1, dy=-8.5)
ax.annotate("", xy=(98.6, 9), xytext=(20, 9), arrowprops=dict(arrowstyle="-|>", color=GRIS, lw=1, ls=":"))
ax.text(58, 10, "collecte des métriques : node_exporter :9100 sur toutes les VM, HAProxy :8404", ha="center", fontsize=7.2, color=GRIS)

plt.savefig(OUT, bbox_inches="tight", facecolor="white")
print("ok", OUT)
