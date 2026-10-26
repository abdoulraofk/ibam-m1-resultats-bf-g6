#!/usr/bin/env bash
# V3 — Montée en charge : « ab -n 2000 -c 50 », à lancer une fois avec
# NB_APP=2 puis une fois avec NB_APP=4 (après « vagrant up » avec la même
# valeur). Mesure : requêtes par seconde dans les deux configurations.
#
# Usage : essais/v3_charge.sh [passes, 3 par défaut]
#         NB_APP=4 essais/v3_charge.sh
#
# Origine de la charge, dans cet ordre :
#   1. ab installé sur l'hôte (Linux, macOS) ;
#   2. ab dans un conteneur Docker (image httpd), si Docker tourne ;
#   3. ab lancé depuis lb1 : la charge partage alors le processeur du
#      répartiteur, ce qui sous-estime le débit — c'est noté dans le résultat.
#
# Honnêteté des mesures : toutes les VM partagent le processeur d'un seul
# PC. Doubler les serveurs ne double pas le débit, et il peut baisser.

ARGS_ESSAI="$*"
source "$(dirname "$0")/commun_essais.sh"
PASSES="${1:-3}"
REQUETES="${REQUETES:-2000}"
CONCURRENCE="${CONCURRENCE:-50}"
CHEMIN="/resultat?matricule=M000042"
N="$(noeuds app | wc -l)"

ouvrir_sortie "v3_charge_${N}serveurs" "V3 — Montée en charge, $N serveurs applicatifs : ab -n $REQUETES -c $CONCURRENCE, $PASSES passes"

lancer_ab() {
    if command -v ab >/dev/null 2>&1; then
        ab -n "$REQUETES" -c "$CONCURRENCE" -s 30 "$URL$CHEMIN"
    elif docker info >/dev/null 2>&1; then
        local hote_url="${URL/localhost/host.docker.internal}"
        hote_url="${hote_url/127.0.0.1/host.docker.internal}"
        MSYS_NO_PATHCONV=1 docker run --rm --add-host=host.docker.internal:host-gateway \
            httpd:2.4-alpine ab -n "$REQUETES" -c "$CONCURRENCE" -s 30 "$hote_url$CHEMIN"
    else
        # Depuis bdd2 : la réplique est au repos pendant la charge, alors que
        # lb1 partage son processeur avec HAProxy et sous-estime le débit.
        vagrant ssh "$ORIGINE_VM" -c "ab -n $REQUETES -c $CONCURRENCE -s 30 'http://$IP_LB$CHEMIN'" 2>/dev/null
    fi
}
# Machine qui émettra la charge si ab n'est disponible ni sur l'hôte ni dans
# Docker : une machine au repos, jamais le répartiteur.
ORIGINE_VM="${ORIGINE_VM:-bdd2}"
IP_LB="$(ip_de lb1)"

if command -v ab >/dev/null 2>&1; then ORIGINE="ab sur l'hôte"
elif docker info >/dev/null 2>&1; then
    ORIGINE="ab dans un conteneur Docker sur l'hôte"
    # Image téléchargée AVANT les mesures : une coupure réseau ne doit pas
    # tomber au milieu d'une passe.
    docker image inspect httpd:2.4-alpine >/dev/null 2>&1 || docker pull -q httpd:2.4-alpine >/dev/null         || { echo "ERREUR : impossible de télécharger l'image httpd:2.4-alpine (réseau ?)" >&2; exit 1; }
else
    ORIGINE="ab depuis $ORIGINE_VM, machine au repos, vers le répartiteur $IP_LB"
    vagrant ssh "$ORIGINE_VM" -c "command -v ab >/dev/null || sudo apt-get install -y -qq apache2-utils >/dev/null 2>&1" >/dev/null 2>&1
fi
log "Origine de la charge : $ORIGINE"
log "Requête : GET $CHEMIN"
log "Concurrence : $CONCURRENCE connexions simultanées, $REQUETES requêtes par passe"
log ""
log "Lire le nombre de réponses non 2xx autant que le débit : au-delà de la"
log "capacité de la plateforme, les 503 sont renvoyés vite et gonflent"
log "artificiellement le nombre de requêtes par seconde."

DEBITS=()
for p in $(seq "$PASSES"); do
    log ""
    log "=== Passe $p / $PASSES"
    lancer_ab > "$SORTIE.passe" 2>&1
    cat "$SORTIE.passe" >> "$SORTIE"
    rps="$(tr -d '\r' < "$SORTIE.passe" | awk '/^Requests per second/ { print $4 }')"
    echecs="$(tr -d '\r' < "$SORTIE.passe" | awk '/^Failed requests/ { print $3 }')"
    non2xx="$(tr -d '\r' < "$SORTIE.passe" | awk '/^Non-2xx responses/ { print $3 }')"
    if [ -n "$rps" ]; then
        DEBITS+=("$rps")
        reussite="$(awk -v n="${non2xx:-0}" -v t="$REQUETES" 'BEGIN { printf "%.1f", 100 * (t - n) / t }')"
        echo "Passe $p : $rps requêtes/s, $echecs échec(s), ${non2xx:-0} réponse(s) non 2xx (réussite : ${reussite} %)" | tee -a "$SORTIE"
        if awk -v r="$reussite" 'BEGIN { exit !(r < 50) }'; then
            echo "  ATTENTION : moins de la moitié des requêtes aboutissent à ce niveau de" | tee -a "$SORTIE"
            echo "  concurrence. Le débit affiché compte aussi les réponses d'erreur," | tee -a "$SORTIE"
            echo "  renvoyées vite : ce n'est pas un débit utile." | tee -a "$SORTIE"
        fi
    else
        faites="$(tr -d '\r' < "$SORTIE.passe" | awk '/^Total of .* requests completed/ { print $3 }')"
        if grep -q "timeout specified has expired" "$SORTIE.passe"; then
            echo "Passe $p : INCOMPLÈTE — ${faites:-?} requêtes sur $REQUETES ont abouti, les autres sont restées sans réponse plus de 30 s (ab s'arrête sans statistiques)" | tee -a "$SORTIE"
        else
            echo "Passe $p : ÉCHEC — ab n'a pas produit de résultat (voir ci-dessus)" | tee -a "$SORTIE"
        fi
    fi
    rm -f "$SORTIE.passe"
    sleep 5
done

log ""
log "=== Synthèse, $N serveurs"
if [ "${#DEBITS[@]}" -gt 0 ]; then
    printf '%s\n' "${DEBITS[@]}" | sort -n | awk -v n="$N" '
        { v[NR] = $1; s += $1 }
        END { printf "Débit (requêtes/s) : médiane %.1f   min %.1f   max %.1f   sur %d passe(s)\n",
                     (NR % 2 ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2), v[1], v[NR], NR
              printf "Ligne pour le dossier : N=%d  ->  %.1f requêtes/s (médiane)\n", n,
                     (NR % 2 ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2) }' | tee -a "$SORTIE"
    CODE=0
else
    log "Aucune passe exploitable."; CODE=1
fi
fermer_sortie
exit "$CODE"
