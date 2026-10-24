#!/usr/bin/env bash
# R2 — Idempotence : « vagrant provision » rejoué deux fois de suite ne
# modifie rien et n'échoue pas.
#
# Méthode : on provisionne une première fois, on relève l'empreinte SHA-256
# de chaque fichier de /etc sur chaque machine, on provisionne une seconde
# fois, on relève à nouveau, et on compare. Toute différence est un défaut
# d'idempotence (ligne ajoutée deux fois, fichier réécrit autrement…).
#
# Usage, depuis la racine du dépôt (Git Bash ou Linux), plateforme démarrée :
#     essais/r2_idempotence.sh              # toutes les machines en marche
#     essais/r2_idempotence.sh bdd1 app1    # machines choisies
#
# Garder les mêmes variables NB_APP / EXT que pour « vagrant up ».
# Sortie brute : essais/resultats/r2_idempotence_<date>.txt

set -euo pipefail
cd "$(dirname "$0")/.."
command -v vagrant >/dev/null 2>&1 || {
    echo "vagrant introuvable. Sous Windows, lancer ce script depuis Git Bash, ou depuis" >&2
    echo "PowerShell avec : essais\lancer.cmd $(basename "$0" .sh)   (pas avec « bash », qui lance WSL)" >&2
    exit 1
}

HORODATAGE="$(date +%Y%m%d_%H%M%S)"
SORTIE="essais/resultats/r2_idempotence_${HORODATAGE}.txt"
TRAVAIL="$(mktemp -d)"
trap 'rm -rf "$TRAVAIL"' EXIT
mkdir -p essais/resultats

# Fichiers qui changent sans lien avec le provisionnement : exclus.
EXCLUS="/etc/mtab|/etc/adjtime|/etc/ld.so.cache|/etc/machine-id|/etc/resolv.conf"

log() { printf '%s\n' "$*" | tee -a "$SORTIE"; }

if [ "$#" -gt 0 ]; then
    MACHINES=("$@")
else
    mapfile -t MACHINES < <(vagrant status --machine-readable | tr -d '\r' \
        | awk -F, '$3 == "state" && $4 == "running" { print $2 }')
fi
[ "${#MACHINES[@]}" -gt 0 ] || { echo "Aucune machine en marche : lancer « vagrant up » d'abord." >&2; exit 1; }

empreintes() {   # empreintes <machine> <fichier de sortie>
    vagrant ssh "$1" -c "sudo find /etc -xdev -type f -print0 2>/dev/null | sudo xargs -0 sha256sum 2>/dev/null | sort -k2" \
        2>/dev/null | tr -d '\r' | grep -Ev "  ($EXCLUS)\$" > "$2"
}

provisionner() {   # provisionner <numéro de passe>
    local debut fin
    debut=$(date +%s)
    log "--- Passe $1 : vagrant provision ${MACHINES[*]}"
    if ! vagrant provision "${MACHINES[@]}" > "$TRAVAIL/passe$1.log" 2>&1; then
        cat "$TRAVAIL/passe$1.log" >> "$SORTIE"
        log "ÉCHEC : la passe $1 a échoué (journal complet ci-dessus)."
        exit 1
    fi
    fin=$(date +%s)
    log "    réussie en $((fin - debut)) s"
}

log "R2 — Idempotence du provisionnement — $(date '+%Y-%m-%d %H:%M:%S')"
log "Poste    : $(hostname)   NB_APP=${NB_APP:-2}   EXT=${EXT:-}"
log "Commit   : $(git log -1 --format='%h %s' 2>/dev/null)"
log "Machines : ${MACHINES[*]}"

provisionner 1
for m in "${MACHINES[@]}"; do empreintes "$m" "$TRAVAIL/$m.avant"; done

provisionner 2
for m in "${MACHINES[@]}"; do empreintes "$m" "$TRAVAIL/$m.apres"; done

log "--- Comparaison des fichiers de /etc entre les deux passes"
DEFAUTS=0
for m in "${MACHINES[@]}"; do
    nb=$(wc -l < "$TRAVAIL/$m.apres")
    if [ "$nb" -eq 0 ]; then
        log "$m : AUCUNE empreinte relevée (vagrant ssh a-t-il échoué ?)"
        DEFAUTS=$((DEFAUTS + 1))
    elif diff -u "$TRAVAIL/$m.avant" "$TRAVAIL/$m.apres" > "$TRAVAIL/$m.diff"; then
        log "$m : OK — $nb fichiers identiques"
    else
        log "$m : MODIFIÉ par la seconde passe :"
        grep -E '^[+-][^+-]' "$TRAVAIL/$m.diff" | awk '
            { s = substr($1, 1, 1); f = $2; vu[f] = vu[f] s }
            END {
                for (f in vu) {
                    etat = (vu[f] ~ /-/ && vu[f] ~ /\+/) ? "modifié " : (vu[f] ~ /\+/ ? "ajouté  " : "supprimé")
                    print "      " etat "  " f
                }
            }' | sort -k2 | tee -a "$SORTIE"
        DEFAUTS=$((DEFAUTS + 1))
    fi
done

if [ "$DEFAUTS" -eq 0 ]; then
    log "RÉSULTAT : R2 satisfaite — la seconde passe n'a rien modifié."
else
    log "RÉSULTAT : R2 NON satisfaite — $DEFAUTS machine(s) en défaut."
fi
log "Sortie brute : $SORTIE"
[ "$DEFAUTS" -eq 0 ]
