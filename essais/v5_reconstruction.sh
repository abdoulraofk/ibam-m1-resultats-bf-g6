#!/usr/bin/env bash
# V5 — Reconstruction : « vagrant destroy -f » puis « vagrant up », sans
# aucune intervention, et mesure de la durée totale (exigence R1).
#
# Usage, depuis la racine du dépôt (Git Bash ou Linux) :
#     essais/v5_reconstruction.sh
#     NB_APP=4 essais/v5_reconstruction.sh
#
# ATTENTION : détruit toutes les machines déclarées avec les variables
# NB_APP / EXT courantes. Utiliser les mêmes que lors de la création,
# sinon des machines restent allumées hors de contrôle de Vagrant.
#
# Sortie brute : essais/resultats/v5_reconstruction_<date>.txt

set -uo pipefail
cd "$(dirname "$0")/.."
command -v vagrant >/dev/null 2>&1 || {
    echo "vagrant introuvable. Sous Windows, lancer ce script depuis Git Bash, ou depuis" >&2
    echo "PowerShell avec : essais\lancer.cmd $(basename "$0" .sh)   (pas avec « bash », qui lance WSL)" >&2
    exit 1
}

[ -f .env ] || { echo "Fichier .env absent : « cp .env.exemple .env » puis le compléter." >&2; exit 1; }
mkdir -p essais/resultats
SORTIE="essais/resultats/v5_reconstruction_$(date +%Y%m%d_%H%M%S).txt"

duree() { printf '%dmin %02ds' $(($1 / 60)) $(($1 % 60)); }

{
    echo "V5 — Reconstruction intégrale — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Poste : $(hostname)   NB_APP=${NB_APP:-2}   EXT=${EXT:-}"
    echo "Commit : $(git log -1 --format='%h %s' 2>/dev/null)"
    echo
} | tee "$SORTIE"

echo "--- vagrant destroy -f" | tee -a "$SORTIE"
vagrant destroy -f >> "$SORTIE" 2>&1

echo "--- vagrant up (chronométré)" | tee -a "$SORTIE"
DEBUT=$(date +%s)
vagrant up >> "$SORTIE" 2>&1
CODE_UP=$?
FIN=$(date +%s)
DUREE=$((FIN - DEBUT))

if [ "$CODE_UP" -ne 0 ]; then
    echo "ÉCHEC : vagrant up a échoué après $(duree $DUREE) (code $CODE_UP) — fin du journal :" | tee -a "$SORTIE"
    tail -20 "$SORTIE" | sed 's/^/    /'
    echo "Sortie brute : $SORTIE"
    exit 1
fi
echo "vagrant up réussi en $(duree $DUREE) ($DUREE s), sans intervention" | tee -a "$SORTIE"
echo | tee -a "$SORTIE"

essais/controle_socle.sh 2>&1 | tee -a "$SORTIE"
CODE_CONTROLE=${PIPESTATUS[0]}

echo | tee -a "$SORTIE"
echo "Durée de reconstruction (mesure V5) : $(duree $DUREE)" | tee -a "$SORTIE"
echo "Sortie brute : $SORTIE"
exit "$CODE_CONTROLE"
