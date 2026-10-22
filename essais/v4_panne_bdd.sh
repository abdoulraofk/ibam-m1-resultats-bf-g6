#!/usr/bin/env bash
# V4 — Panne de la base primaire : « vagrant halt bdd1 ».
# Attendu : /sante renvoie proprement 503 (jamais une page blanche ni une
# erreur de connexion brute), puis la procédure de bascule rétablit le
# service sur bdd2.
# Mesure : temps total de la procédure de bascule.
#
# Usage : essais/v4_panne_bdd.sh
# La bascule est lancée depuis l'hôte : bash scripts/bascule.sh (KAGAMBEGA).
#
# ATTENTION : après V4, bdd2 est la base primaire et bdd1 est arrêtée.
# Ne pas relancer bdd1 telle quelle (deux bases accepteraient les
# écritures) : revenir à l'état initial avec essais/v5_reconstruction.sh.

ARGS_ESSAI="$*"
source "$(dirname "$0")/commun_essais.sh"

ouvrir_sortie v4_panne_bdd "V4 — Panne de la base primaire bdd1 et bascule sur bdd2"

# etat_sante : « code type-de-contenu » de GET /sante, corps dans $CORPS
#   À appeler directement, pas dans $( ) : un sous-shell perdrait CORPS.
etat_sante() {
    local f; f="$(mktemp)"
    ETAT="$(curl -s -o "$f" -m 5 -w '%{http_code} %{content_type}' "$URL/sante")"
    CORPS="$(tr -d '\r\n' < "$f" | head -c 200)"; rm -f "$f"
}

etat_sante; e="$ETAT"
log "Avant la panne : /sante -> $e  $CORPS"
[ "${e%% *}" = 200 ] || { log "ERREUR : le service n'est pas sain avant la panne, essai annulé"; fermer_sortie; exit 1; }

log ""
T0=$(ms)
log "--- Panne : vagrant halt bdd1 ($(date '+%H:%M:%S'))"
vagrant halt bdd1 >> "$SORTIE" 2>&1
log "bdd1 arrêtée après $(( ($(ms) - T0) / 1000 )) s"

log ""
log "--- Réaction du service (relevé toutes les 0,5 s pendant 10 s)"
PROPRE=oui
for _ in $(seq 20); do
    etat_sante; e="$ETAT"
    log "$(awk -v t="$(( $(ms) - T0 ))" 'BEGIN { printf "+%4.1f s", t / 1000 }')  /sante -> $e  $CORPS"
    code="${e%% *}"
    case "$code" in
        503) grep -qiE 'connection to server|refused|traceback|psycopg' <<< "$CORPS" && PROPRE=non ;;
        000|"") PROPRE=non ;;   # pas de réponse du tout
        200) ;;                 # encore servi (requête en cours) : toléré
        *) PROPRE=non ;;
    esac
    sleep 0.5
done
log ""
if [ "$PROPRE" = oui ]; then log "Réponses pendant la panne : propres (503, sans erreur brute de la base)"
else log "Réponses pendant la panne : NON conformes (voir ci-dessus : erreur brute, page vide ou absence de réponse)"; fi

log ""
if [ -f scripts/bascule.sh ]; then
    log "--- Bascule : bash scripts/bascule.sh"
    TB=$(ms)
    bash scripts/bascule.sh >> "$SORTIE" 2>&1
    CODE_B=$?
    DUREE_B=$(( $(ms) - TB ))
    log "bascule.sh terminé en $(( DUREE_B / 1000 )) s (code $CODE_B)"
    log "--- Attente du retour du service (jusqu'à 120 s)"
    RETOUR=""
    for _ in $(seq 240); do
        etat_sante; e="$ETAT"
        if [ "${e%% *}" = 200 ]; then RETOUR=$(ms); break; fi
        sleep 0.5
    done
    if [ -n "$RETOUR" ]; then
        log "Service rétabli : /sante -> $e  $CORPS"
        log ""
        log "Temps total de la procédure (panne -> service rétabli) : $(( (RETOUR - T0) / 1000 )) s"
        log "  dont exécution de bascule.sh                          : $(( DUREE_B / 1000 )) s"
        r="$(vagrant ssh bdd2 -c "sudo -u postgres psql -qtAc 'SELECT pg_is_in_recovery()'" 2>/dev/null | tr -d '\r' | tail -1)"
        log "bdd2 en réplique : ${r:-?} (attendu : f, bdd2 est devenue primaire)"
        [ "$PROPRE" = oui ] && { log "RÉSULTAT : V4 satisfait"; CODE=0; } || { log "RÉSULTAT : V4 partiel (bascule réussie, réponses pendant la panne non conformes)"; CODE=1; }
    else
        log "RÉSULTAT : V4 NON satisfait — service non rétabli 120 s après la bascule"; CODE=1
    fi
else
    log "scripts/bascule.sh absent : seule la réaction à la panne est mesurée."
    log "RÉSULTAT : V4 incomplet (bascule à écrire)"; CODE=1
fi
log ""
log "Retour à l'état initial : essais/v5_reconstruction.sh (ne pas relancer bdd1 seule)."
fermer_sortie
exit "$CODE"
