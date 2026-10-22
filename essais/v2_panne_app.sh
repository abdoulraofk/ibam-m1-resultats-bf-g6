#!/usr/bin/env bash
# V2 — Panne d'un serveur applicatif : « vagrant halt app1 » pendant une
# charge continue. Le service doit rester disponible ; plus aucune erreur
# au-delà de 5 secondes.
# Mesures : nombre de requêtes perdues et durée de la période dégradée.
#
# Usage : essais/v2_panne_app.sh [machine, app1 par défaut] [durée s, 40]
# La machine arrêtée est redémarrée à la fin (« vagrant up »).

ARGS_ESSAI="$*"
source "$(dirname "$0")/commun_essais.sh"
CIBLE="${1:-app1}"
DUREE="${2:-40}"
TRAVAIL="$(mktemp)"; trap 'rm -f "$TRAVAIL"' EXIT

ouvrir_sortie v2_panne_app "V2 — Panne de $CIBLE pendant une charge continue de $DUREE s"
noeuds app | grep -qx "$CIBLE" || { log "ERREUR : $CIBLE n'est pas un serveur applicatif déclaré"; exit 1; }

log "--- Charge continue sur $URL/info (4 clients en boucle), panne à +10 s"
charge_continue "$URL/info" "$DUREE" "$TRAVAIL" 4 &
CHARGE=$!
sleep 10
T0=$(ms)
log "Panne : vagrant halt $CIBLE ($(date '+%H:%M:%S'))"
vagrant halt "$CIBLE" >> "$SORTIE" 2>&1
log "$CIBLE arrêtée après $(( ($(ms) - T0) / 1000 )) s"
wait "$CHARGE"

log ""
log "--- Bilan"
bilan_charge "$TRAVAIL" "$T0" | tee -a "$SORTIE"
TARDIVES="$(awk -v t0="$T0" '$2 != "200" && $1 - t0 > 5000' "$TRAVAIL" | wc -l)"
log "Erreurs plus de 5 s après la panne : $TARDIVES"
log "Répartition des codes HTTP :"
awk '{ print $2 }' "$TRAVAIL" | sort | uniq -c | tee -a "$SORTIE"
log ""
if [ "$TARDIVES" -eq 0 ]; then log "RÉSULTAT : V2 satisfait (aucune erreur au-delà de 5 s)"; CODE=0
else log "RÉSULTAT : V2 NON satisfait ($TARDIVES erreur(s) au-delà de 5 s)"; CODE=1; fi

log ""
log "--- Remise en service : vagrant up $CIBLE"
vagrant up "$CIBLE" >> "$SORTIE" 2>&1 && log "$CIBLE redémarrée" || log "ATTENTION : $CIBLE n'a pas redémarré"
log ""
log "--- Horodatages bruts (ms, code HTTP)"
sort -n "$TRAVAIL" >> "$SORTIE"
fermer_sortie
exit "$CODE"
