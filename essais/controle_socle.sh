#!/usr/bin/env bash
# Contrôle de la plateforme après un « vagrant up » : chaque point est
# affiché OK ou KO, et le script se termine en erreur s'il y a un KO.
#
# Sert à valider le jalon du soir après la reconstruction croisée, et
# termine le scénario V5 (essais/v5_reconstruction.sh).
#
# Usage, depuis la racine du dépôt (Git Bash ou Linux) :
#     essais/controle_socle.sh
# Garder les mêmes variables NB_APP / EXT que pour « vagrant up ».

set -uo pipefail
cd "$(dirname "$0")/.."
command -v vagrant >/dev/null 2>&1 || {
    echo "vagrant introuvable. Sous Windows, lancer ce script depuis Git Bash, ou depuis" >&2
    echo "PowerShell avec : essais\lancer.cmd $(basename "$0" .sh)   (pas avec « bash », qui lance WSL)" >&2
    exit 1
}

URL="${URL:-http://localhost:8080}"
NOEUDS_YML="config/noeuds.yml"
BDD_NOM="$(grep -E '^BDD_NOM=' .env 2>/dev/null | cut -d= -f2 | tr -d '\r')"
BDD_NOM="${BDD_NOM:-resultats}"
KO=0

ok() { printf '  OK  %s\n' "$*"; }
ko() { printf '  KO  %s\n' "$*"; KO=$((KO + 1)); }

# Machines déclarées, lues dans config/noeuds.yml (clés « :nom: » ou « nom: »)
noeuds() {   # noeuds [rôle]  ->  une ligne « nom » par machine
    tr -d '\r' < "$NOEUDS_YML" | awk -v voulu="${1:-}" '
        function emettre() { if (nom != "" && (voulu == "" || r == voulu)) print nom; nom = r = "" }
        /^-/ { emettre(); sub(/^-[ ]*/, "") }
        { l = $0; sub(/^[ ]+/, "", l); sub(/^:/, "", l); i = index(l, ":"); if (!i) next
          k = substr(l, 1, i - 1); v = substr(l, i + 1); gsub(/^[ ]+|[ ]+$|["\047]/, "", v)
          if (k == "nom") nom = v; else if (k == "role") r = v }
        END { emettre() }'
}

sql() {   # sql <machine> <requête>  ->  résultat brut
    vagrant ssh "$1" -c "sudo -u postgres psql -qtA -d $BDD_NOM -c \"$2\"" 2>/dev/null | tr -d '\r' | tail -1
}

[ -f "$NOEUDS_YML" ] || { echo "$NOEUDS_YML absent : lancer « vagrant up » d'abord." >&2; exit 1; }
mapfile -t TOUTES < <(noeuds)
mapfile -t APPS < <(noeuds app)

echo "Contrôle du socle — $(date '+%Y-%m-%d %H:%M:%S') — ${#TOUTES[@]} machines, ${#APPS[@]} serveurs applicatifs"

echo "[1] Machines démarrées"
ETATS="$(vagrant status --machine-readable 2>/dev/null | tr -d '\r' | awk -F, '$3 == "state" { print $2, $4 }')"
for m in "${TOUTES[@]}"; do
    etat="$(awk -v m="$m" '$1 == m { print $2 }' <<< "$ETATS")"
    [ "$etat" = running ] && ok "$m en marche" || ko "$m : ${etat:-inconnue}"
done

echo "[2] Base de données"
n="$(sql bdd1 'SELECT count(*) FROM resultats')"
[ "${n:-0}" -ge 50000 ] 2>/dev/null && ok "bdd1 : $n lignes dans resultats" || ko "bdd1 : table resultats absente ou incomplète (${n:-aucune réponse})"
r="$(sql bdd2 'SELECT pg_is_in_recovery()')"
[ "$r" = t ] && ok "bdd2 est une réplique en lecture" || ko "bdd2 n'est pas en réplique (${r:-aucune réponse})"

echo "[3] Service via le répartiteur ($URL)"
code="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "$URL/sante")"
[ "$code" = 200 ] && ok "/sante répond 200" || ko "/sante répond ${code:-rien} (app.sh encore provisoire ?)"
code="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "$URL/resultat?matricule=M000001")"
[ "$code" = 200 ] && ok "/resultat?matricule=M000001 répond 200" || ko "/resultat répond ${code:-rien}"

echo "[4] Répartition sur les ${#APPS[@]} serveurs (V1 simplifié)"
vus="$(for _ in $(seq $((4 * ${#APPS[@]}))); do curl -s -m 5 "$URL/info"; echo; done | grep -v '^$' | sort -u)"
nb_vus="$(grep -c . <<< "$vus")"
if [ "$nb_vus" -eq "${#APPS[@]}" ]; then ok "les ${#APPS[@]} serveurs répondent : $(echo $vus)"
else ko "$nb_vus serveur(s) vu(s) sur ${#APPS[@]} : $(echo $vus)"; fi

echo
if [ "$KO" -eq 0 ]; then echo "RÉSULTAT : plateforme conforme"; else echo "RÉSULTAT : $KO point(s) KO"; fi
[ "$KO" -eq 0 ]
