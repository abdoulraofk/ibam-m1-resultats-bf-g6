#!/usr/bin/env bash
# V6 — Panne du répartiteur (extension E1) : « vagrant halt lb1 ».
# Le service doit rester joignable à la même adresse : l'IP virtuelle
# VRRP (.10 du sous-réseau), portée par lb1 puis reprise par lb2.
# Mesure : plus longue interruption du service (plus long intervalle sans
# aucune réponse 200) après le « vagrant halt ». On ne prend pas « panne ->
# dernière erreur » : « vagrant halt » met jusqu'à 30 s à éteindre lb1, qui
# sert normalement pendant ce temps, et une requête coupée en vol n'est
# notée en erreur qu'à la fin de son délai de 10 s (curl -m 10).
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
if [ "$code" != 200 ]; then
    log "ERREUR : $URL/info répond « $code » avant la panne."
    log "  Code 000 : l'IP virtuelle est injoignable. Causes habituelles :"
    log "  un VPN actif capte le trafic vers 192.168.61.0/24 (le désactiver"
    log "  pendant les essais), ou keepalived n'a pas démarré sur lb1."
    fermer_sortie; exit 1
fi
log "Avant la panne : $URL/info servi par lb1 -> 200"

log ""
log "--- Charge continue sur $URL/info, panne de lb1 à +10 s"
DEBUT=$(ms); FIN=$(( DEBUT + DUREE * 1000 ))
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
# Plus long intervalle sans réponse 200 après la panne (fin de la charge comprise)
read -r COUPURE A B <<< "$(sort -n "$TRAVAIL" | awk -v t0="$T0" -v fin="$FIN" '
    $2 == "200" { if (prec && $1 >= t0 && $1 - prec > max) { max = $1 - prec; a = prec; b = $1 } prec = $1 }
    END { if (fin > prec && fin - prec > max) { max = fin - prec; a = prec; b = fin }
          print max + 0, a + 0, b + 0 }')"
if [ "$COUPURE" -gt 0 ]; then
    log "Interruption maximale : $(awk -v c="$COUPURE" 'BEGIN { printf "%.1f", c / 1000 }') s, de +$(awk -v x="$A" -v t="$T0" 'BEGIN { printf "%.1f", (x - t) / 1000 }') s à +$(awk -v x="$B" -v t="$T0" 'BEGIN { printf "%.1f", (x - t) / 1000 }') s après « vagrant halt »"
fi
# Preuve de la bascule : moment où lb2 prend l'IP virtuelle (journal keepalived)
log "Journal keepalived de lb2 :"
vagrant ssh lb2 -c "sudo journalctl -u keepalived -o short-precise --since '@$(( T0 / 1000 - 5 ))' --no-pager | grep -E 'MASTER|BACKUP'" 2>/dev/null \
    | tr -d '\r' | sed 's/^/    /' | tee -a "$SORTIE"
log ""
if [ "$COUPURE" -lt 5000 ]; then log "RÉSULTAT : V6 satisfait (service jamais interrompu plus de 5 s, à la même adresse)"; CODE=0
else log "RÉSULTAT : V6 NON satisfait (interruption de plus de 5 s)"; CODE=1; fi

log ""
log "--- Remise en service : vagrant up lb1"
vagrant up lb1 >> "$SORTIE" 2>&1 && log "lb1 redémarrée" || log "ATTENTION : lb1 n'a pas redémarré"
log ""
log "--- Horodatages bruts (ms, code HTTP)"
sort -n "$TRAVAIL" >> "$SORTIE"
fermer_sortie
exit "$CODE"
