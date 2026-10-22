#!/usr/bin/env bash
# Fonctions partagées par les scripts d'essai, exécutés sur l'HÔTE
# (Git Bash ou Linux), depuis la racine du dépôt.
#
# Chaque essai écrit sa sortie brute dans essais/resultats/<essai>_<date>.txt,
# avec en tête tout ce qu'il faut pour la reproduire : commande, date,
# poste, NB_APP, EXT et commit. Une mesure sans ce contexte ne vaut rien
# (pénalité de 4 points pour les mesures non reproductibles).

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v vagrant >/dev/null 2>&1 || {
    echo "vagrant introuvable. Sous Windows, lancer depuis Git Bash, ou depuis" >&2
    echo "PowerShell avec : essais\\lancer.cmd <essai>   (pas avec « bash », qui lance WSL)" >&2
    exit 1
}

URL="${URL:-http://localhost:8080}"
NOEUDS_YML="config/noeuds.yml"
SORTIE=""

# ouvrir_sortie <nom de l'essai> <description> : crée le fichier de résultat
ouvrir_sortie() {
    mkdir -p essais/resultats
    SORTIE="essais/resultats/$1_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "$2"
        echo "Commande : $0 ${ARGS_ESSAI:-}"
        echo "Date     : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Poste    : $(hostname)   NB_APP=${NB_APP:-2}   EXT=${EXT:-}"
        echo "Commit   : $(git log -1 --format='%h %s' 2>/dev/null)"
        echo "Adresse  : $URL"
        echo
    } > "$SORTIE"
    cat "$SORTIE"
}

log() { printf '%s\n' "$*" | tee -a "$SORTIE"; }

fermer_sortie() { echo "Sortie brute : $SORTIE"; }

# Horodatage en millisecondes
ms() { date +%s%3N; }

# noeuds [rôle] : noms des machines déclarées dans config/noeuds.yml
noeuds() {
    [ -f "$NOEUDS_YML" ] || { echo "$NOEUDS_YML absent : lancer « vagrant up » d'abord." >&2; exit 1; }
    tr -d '\r' < "$NOEUDS_YML" | awk -v voulu="${1:-}" '
        function emettre() { if (nom != "" && (voulu == "" || r == voulu)) print nom; nom = r = "" }
        /^-/ { emettre(); sub(/^-[ ]*/, "") }
        { l = $0; sub(/^[ ]+/, "", l); sub(/^:/, "", l); i = index(l, ":"); if (!i) next
          k = substr(l, 1, i - 1); v = substr(l, i + 1); gsub(/^[ ]+|[ ]+$|["\047]/, "", v)
          if (k == "nom") nom = v; else if (k == "role") r = v }
        END { emettre() }'
}

# ip_de <machine> : adresse lue dans config/noeuds.yml (une seule ligne :
# « exit » passe par END, qui ne doit pas l'afficher une seconde fois)
ip_de() {
    tr -d '\r' < "$NOEUDS_YML" | awk -v voulu="$1" '
        /^-/ { if (nom == voulu && ip != "") { print ip; trouve = 1; exit } nom = ip = ""; sub(/^-[ ]*/, "") }
        { l = $0; sub(/^[ ]+/, "", l); sub(/^:/, "", l); i = index(l, ":"); if (!i) next
          k = substr(l, 1, i - 1); v = substr(l, i + 1); gsub(/^[ ]+|[ ]+$|["\047]/, "", v)
          if (k == "nom") nom = v; else if (k == "ip") ip = v }
        END { if (!trouve && nom == voulu && ip != "") print ip }'
}

# machine_qui_repond <url> : nom de la machine renvoyé par /info (JSON ou texte)
machine_qui_repond() {
    curl -s -m 5 "$1" | tr -d '\r' | sed -n 's/.*"machine" *: *"\([^"]*\)".*/\1/p; t; p' | head -1
}

# charge_continue <url> <durée s> <fichier> <parallèles> :
#   envoie des requêtes en boucle et note « horodatage_ms code_http » par ligne
charge_continue() {
    local url="$1" duree="$2" fichier="$3" paralleles="${4:-2}" fin i
    fin=$(( $(ms) + duree * 1000 ))
    : > "$fichier"
    for i in $(seq "$paralleles"); do
        (
            while [ "$(ms)" -lt "$fin" ]; do
                c="$(curl -s -o /dev/null -w '%{http_code}' -m 10 "$url")"
                echo "$(ms) $c" >> "$fichier"
            done
        ) &
    done
    wait
}

# bilan_charge <fichier> <t0_ms> : requêtes, erreurs, période dégradée
bilan_charge() {
    sort -n "$1" | awk -v t0="$2" '
        { n++; if ($2 != "200") { e++; if (!p) p = $1; d = $1 } }
        END {
            printf "Requêtes envoyées      : %d\n", n
            printf "Requêtes en erreur     : %d (%.1f %%)\n", e, (n ? 100 * e / n : 0)
            if (e) printf "Période dégradée       : de +%.1f s à +%.1f s après la panne, soit %.1f s\n", (p - t0) / 1000, (d - t0) / 1000, (d - p) / 1000
            else   printf "Période dégradée       : aucune (0 erreur)\n"
        }'
}
