#!/usr/bin/env bash
# R6 — Bascule de la base sur bdd2. À lancer depuis l'HÔTE, à la racine du
# dépôt (Git Bash ou Linux), quand bdd1 est en panne :
#
#     bash scripts/bascule.sh             # bdd1 doit être arrêtée
#     bash scripts/bascule.sh --forcer    # arrête d'abord PostgreSQL sur bdd1
#
# Responsable : KAGAMBEGA — version écrite par KUELA le 24/10, le script
# n'ayant pas été poussé avant le gel. Chronométrée par essais/v4_panne_bdd.sh.
#
# Étapes, chacune chronométrée :
#   1. bdd1 ne doit plus accepter d'écritures : sinon deux bases primaires
#      divergeraient. Sans --forcer, on refuse si bdd1 est en marche.
#   2. Promotion de bdd2 (pg_promote) : la réplique devient primaire.
#   3. Chaque serveur applicatif pointe sur bdd2 : réécriture de
#      /etc/resultats-app/bdd_hote.env, relu à chaque requête (CONTRATS.md),
#      donc sans redémarrer l'application.
#   4. Vérification : /sante répond 200 à travers le répartiteur.
#
# Rejouable : si bdd2 est déjà primaire, l'étape 2 est sautée.
# Retour à la normale : essais/v5_reconstruction.sh (ne pas relancer bdd1
# seule : elle se croirait encore primaire).

set -uo pipefail
cd "$(dirname "$0")/.."
URL="${URL:-http://localhost:8080}"
FORCER=non; [ "${1:-}" = "--forcer" ] && FORCER=oui

ms() { date +%s%3N; }
DEBUT=$(ms)
etape() { printf '[bascule +%5.1f s] %s\n' "$(awk -v t="$(( $(ms) - DEBUT ))" 'BEGIN { print t / 1000 }')" "$*"; }
echec() { etape "ÉCHEC : $*"; exit 1; }
sur() { vagrant ssh "$1" -c "$2" 2>/dev/null | tr -d '\r'; }

command -v vagrant >/dev/null 2>&1 || echec "vagrant introuvable (lancer depuis Git Bash, pas WSL)"
[ -f config/noeuds.yml ] || echec "config/noeuds.yml absent : la plateforme n'a pas été créée"

ip_de() {
    tr -d '\r' < config/noeuds.yml | awk -v voulu="$1" '
        /^-/ { if (nom == voulu && ip != "") { print ip; t = 1; exit } nom = ip = ""; sub(/^-[ ]*/, "") }
        { l = $0; sub(/^[ ]+/, "", l); sub(/^:/, "", l); i = index(l, ":"); if (!i) next
          k = substr(l, 1, i - 1); v = substr(l, i + 1); gsub(/^[ ]+|[ ]+$|["\047]/, "", v)
          if (k == "nom") nom = v; else if (k == "ip") ip = v }
        END { if (!t && nom == voulu && ip != "") print ip }'
}
apps() {
    tr -d '\r' < config/noeuds.yml | awk '
        function e() { if (nom != "" && r == "app") print nom; nom = r = "" }
        /^-/ { e(); sub(/^-[ ]*/, "") }
        { l = $0; sub(/^[ ]+/, "", l); sub(/^:/, "", l); i = index(l, ":"); if (!i) next
          k = substr(l, 1, i - 1); v = substr(l, i + 1); gsub(/^[ ]+|[ ]+$|["\047]/, "", v)
          if (k == "nom") nom = v; else if (k == "role") r = v }
        END { e() }'
}
etat_vm() { vagrant status "$1" --machine-readable 2>/dev/null | tr -d '\r' | awk -F, '$3 == "state" { print $4; exit }'; }

IP_BDD2="$(ip_de bdd2)"
[ -n "$IP_BDD2" ] || echec "bdd2 absente de config/noeuds.yml"
mapfile -t APPS < <(apps)
etape "début : bascule de la base vers bdd2 ($IP_BDD2), serveurs : ${APPS[*]}"

# --- 1. bdd1 ne doit plus accepter d'écritures -----------------------------
if [ "$(etat_vm bdd1)" = running ]; then
    if [ "$FORCER" = non ]; then
        echec "bdd1 est en marche : la promouvoir créerait deux bases primaires. Relancer avec --forcer pour arrêter d'abord PostgreSQL sur bdd1."
    fi
    etape "1. --forcer : arrêt de PostgreSQL sur bdd1"
    sur bdd1 "sudo systemctl stop postgresql@16-main" >/dev/null
else
    etape "1. bdd1 arrêtée ($(etat_vm bdd1)) : pas de risque de double primaire"
fi

# --- 2. Promotion de bdd2 ----------------------------------------------------
[ "$(etat_vm bdd2)" = running ] || echec "bdd2 n'est pas en marche"
EN_REPLIQUE="$(sur bdd2 "sudo -u postgres psql -qtAc 'SELECT pg_is_in_recovery()'" | tail -1)"
case "$EN_REPLIQUE" in
    t)  etape "2. promotion de bdd2 (pg_promote)"
        R="$(sur bdd2 "sudo -u postgres psql -qtAc 'SELECT pg_promote(true, 30)'" | tail -1)"
        [ "$R" = t ] || echec "pg_promote a répondu « $R »"
        etape "   bdd2 est primaire" ;;
    f)  etape "2. bdd2 est déjà primaire : promotion sautée" ;;
    *)  echec "bdd2 ne répond pas (« $EN_REPLIQUE »)" ;;
esac

# --- 3. Les serveurs applicatifs pointent sur bdd2 ---------------------------
etape "3. BDD_HOTE=$IP_BDD2 sur ${#APPS[@]} serveur(s), sans redémarrage"
for a in "${APPS[@]}"; do
    (
        if [ "$(etat_vm "$a")" != running ]; then
            etape "   $a arrêtée : ignorée (à reprovisionner plus tard)"; exit 0
        fi
        sur "$a" "echo 'BDD_HOTE=$IP_BDD2' | sudo tee /etc/resultats-app/bdd_hote.env >/dev/null"
        v="$(sur "$a" "cat /etc/resultats-app/bdd_hote.env" | tail -1)"
        [ "$v" = "BDD_HOTE=$IP_BDD2" ] && etape "   $a -> bdd2" || etape "   $a : ÉCHEC de la mise à jour (« $v »)"
    ) &
done
wait

# --- 4. Vérification ---------------------------------------------------------
etape "4. attente de /sante = 200 via $URL"
for _ in $(seq 60); do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' -m 3 "$URL/sante")" = 200 ]; then
        etape "terminé : service rétabli sur bdd2"
        exit 0
    fi
    sleep 0.5
done
echec "/sante ne répond toujours pas 200 après 30 s"
