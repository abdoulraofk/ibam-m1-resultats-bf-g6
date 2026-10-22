#!/usr/bin/env bash
# V6 — Panne du répartiteur (extension E1) : « vagrant halt lb1 ».
# Le service doit rester joignable à la même adresse : l'IP virtuelle
# VRRP (.10 du sous-réseau), portée par lb1 puis reprise par lb2.
# Mesure : temps de reprise après la bascule VRRP.
#
# Usage : EXT=e1 essais/v6_panne_lb.sh [durée s, 40]
# On interroge l'IP virtuelle directement par le réseau privé (l'hôte y
# a accès) : localhost:8080 n'est redirigé que vers lb1 et tombe avec lui.
# lb1 est redémarrée à la fin.

ARGS_ESSAI="$*"
source "$(dirname "$0")/commun_essais.sh"
DUREE="${1:-40}"
TRAVAIL="$(mktemp)"; trap 'rm -f "$TRAVAIL"' EXIT

IP_LB1="$(ip_de lb1)"
VIP="${VIP:-${IP_LB1%.*}.10}"
URL="http://$VIP"
ouvrir_sortie v6_panne_lb "V6 — Panne de lb1, service attendu sur l'IP virtuelle $VIP"

if ! noeuds | grep -qx lb2; then
    log "lb2 n'est pas déclarée : relancer avec EXT=e1 (vagrant up puis cet essai)."
    log "RÉSULTAT : V6 non exécuté (extension E1 absente)"
    fermer_sortie; exit 1
fi
code="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "$URL/info")"
[ "$code" = 200 ] || { log "ERREUR : $URL/info répond « $code » avant la panne (VRRP actif ?)"; fermer_sortie; exit 1; }
log "Avant la panne : $URL/info servi par lb1 -> 200"

log ""
log "--- Charge continue sur $URL/info, panne de lb1 à +10 s"
charge_continue "$URL/info" "$DUREE" "$TRAVAIL" 4 &
CHARGE=$!
sleep 10
T0=$(ms)
log "Panne : vagrant halt lb1 ($(date '+%H:%M:%S'))"
vagrant halt lb1 >> "$SORTIE" 2>&1
wait "$CHARGE"

log ""
log "--- Bilan"
bilan_charge "$TRAVAIL" "$T0" | tee -a "$SORTIE"
DERNIERE="$(sort -n "$TRAVAIL" | awk '$2 != "200" { d = $1 } END { print d + 0 }')"
if [ "$DERNIERE" -gt 0 ]; then
    REPRISE=$(( DERNIERE - T0 ))
    log "Temps de reprise (panne -> dernière erreur) : $(awk -v t="$REPRISE" 'BEGIN { printf "%.1f", t / 1000 }') s"
else
    REPRISE=0; log "Temps de reprise : aucune requête perdue"
fi
log ""
if [ "$REPRISE" -lt 5000 ]; then log "RÉSULTAT : V6 satisfait (service repris en moins de 5 s à la même adresse)"; CODE=0
else log "RÉSULTAT : V6 NON satisfait (reprise en plus de 5 s)"; CODE=1; fi

log ""
log "--- Remise en service : vagrant up lb1"
vagrant up lb1 >> "$SORTIE" 2>&1 && log "lb1 redémarrée" || log "ATTENTION : lb1 n'a pas redémarré"
log ""
log "--- Horodatages bruts (ms, code HTTP)"
sort -n "$TRAVAIL" >> "$SORTIE"
fermer_sortie
exit "$CODE"
