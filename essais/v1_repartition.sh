#!/usr/bin/env bash
# V1 — Répartition : N appels successifs à /info ; les serveurs doivent
# apparaître tour à tour.
# Mesure : écart entre le serveur le plus et le moins sollicité, rapporté à
# la moyenne, (max − min) / moyenne ; attendu < 20 %.
#
# Usage : essais/v1_repartition.sh [nombre d'appels, 20 par défaut]
#         NB_APP=4 essais/v1_repartition.sh

ARGS_ESSAI="$*"
source "$(dirname "$0")/commun_essais.sh"
APPELS="${1:-20}"

ouvrir_sortie v1_repartition "V1 — Répartition des requêtes ($APPELS appels à /info)"
mapfile -t APPS < <(noeuds app)
log "Serveurs déclarés : ${APPS[*]} (${#APPS[@]})"
log ""
log "--- Réponses brutes, dans l'ordre"
REPONSES="$(for _ in $(seq "$APPELS"); do machine_qui_repond "$URL/info"; done)"
printf '%s\n' "$REPONSES" | nl -w3 -s'  ' | tee -a "$SORTIE"

log ""
log "--- Décompte par serveur"
for a in "${APPS[@]}"; do
    printf '%-6s %3d\n' "$a" "$(grep -cx "$a" <<< "$REPONSES")"
done | tee -a "$SORTIE"
autres="$(grep -vxF -f <(printf '%s\n' "${APPS[@]}") <<< "$REPONSES" | grep -c .)"
[ "$autres" -gt 0 ] && log "Réponses non attribuées (erreurs) : $autres"

log ""
for a in "${APPS[@]}"; do grep -cx "$a" <<< "$REPONSES"; done | awk -v n="${#APPS[@]}" -v total="$APPELS" '
    NR == 1 { max = min = $1 } { s += $1; if ($1 > max) max = $1; if ($1 < min) min = $1 }
    END {
        moy = total / n; ecart = (moy ? 100 * (max - min) / moy : 0)
        printf "Plus sollicité : %d   moins sollicité : %d   moyenne : %.1f\n", max, min, moy
        printf "Écart (max − min) / moyenne : %.1f %%\n", ecart
        printf "RÉSULTAT : %s\n", (ecart < 20 && min > 0) ? "V1 satisfait (écart < 20 %)" : "V1 NON satisfait"
        exit !(ecart < 20 && min > 0)
    }' | tee -a "$SORTIE"
CODE=${PIPESTATUS[1]}
fermer_sortie
exit "$CODE"
