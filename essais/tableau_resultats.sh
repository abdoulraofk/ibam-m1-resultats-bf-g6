#!/usr/bin/env bash
# Produit le tableau des résultats V1 à V6 pour le dossier, en lisant les
# sorties brutes de essais/resultats/. Aucun chiffre n'est recopié à la
# main : chaque ligne cite le fichier dont elle vient.
#
# Usage, depuis la racine du dépôt :
#     essais/tableau_resultats.sh              # le plus récent de chaque essai
#     essais/tableau_resultats.sh --tous       # toutes les exécutions
#     essais/tableau_resultats.sh > docs/resultats.md
#
# Ce script ne lance aucun essai et ne touche à aucune machine : il ne fait
# que lire les fichiers déjà produits.

set -uo pipefail
cd "$(dirname "$0")/.."
DOSSIER="essais/resultats"
TOUS=non; [ "${1:-}" = "--tous" ] && TOUS=oui

[ -d "$DOSSIER" ] || { echo "$DOSSIER introuvable." >&2; exit 1; }

# valeur <fichier> <motif awk> : première valeur trouvée, nettoyée
valeur() { tr -d '\r' < "$1" | sed -n "$2" | head -1 | sed 's/^[ \t]*//; s/[ \t]*$//'; }

# contexte <fichier> : « poste, NB_APP=n » pris dans l'en-tête
contexte() {
    tr -d '\r' < "$1" | awk -F: '/^Poste/ { gsub(/^[ ]+/, "", $2); print $2; exit }' \
        | sed 's/  */ /g; s/^ //; s/ $//'
}

fichiers() {   # fichiers <préfixe> : le plus récent, ou tous
    local liste; liste="$(ls -1t "$DOSSIER"/$1*.txt 2>/dev/null)"
    [ -z "$liste" ] && return
    [ "$TOUS" = oui ] && printf '%s\n' "$liste" || printf '%s\n' "$liste" | head -1
}

ligne() {   # ligne <N°> <intitulé> <préfixe> <motif sed> <unité attendue>
    local n="$1" titre="$2" prefixe="$3" motif="$4" f v c
    local trouve=non
    while read -r f; do
        [ -z "$f" ] && continue
        v="$(valeur "$f" "$motif")"
        c="$(contexte "$f")"
        [ -z "$v" ] && v="*(valeur absente de la sortie)*"
        printf '| %s | %s | %s | %s | `%s` |\n' "$n" "$titre" "$v" "$c" "$(basename "$f")"
        trouve=oui
    done < <(fichiers "$prefixe")
    [ "$trouve" = non ] && printf '| %s | %s | **à mesurer** | — | — |\n' "$n" "$titre"
}

echo "# Résultats des scénarios de validation"
echo
echo "Tableau engendré par \`essais/tableau_resultats.sh\` le $(date '+%Y-%m-%d à %H:%M')."
echo "Chaque valeur est lue dans la sortie brute citée en dernière colonne ;"
echo "ces fichiers sont versionnés dans \`essais/resultats/\`."
echo
echo "| N° | Mesure | Résultat | Conditions | Sortie brute |"
echo "| --- | --- | --- | --- | --- |"

ligne V1 "Écart de répartition (max − min) / moyenne" v1_repartition_ 's/^Écart (max − min) \/ moyenne : //p'
ligne V2 "Requêtes en erreur pendant la panne d'un serveur" v2_panne_app_ 's/^Requêtes en erreur *: //p'
ligne V2 "Erreurs plus de 5 s après la panne" v2_panne_app_ 's/^Erreurs plus de 5 s après la panne : //p'
ligne V3 "Débit, 2 serveurs" v3_charge_2serveurs_ 's/^Ligne pour le dossier : N=2  ->  //p'
ligne V3 "Débit, 4 serveurs" v3_charge_4serveurs_ 's/^Ligne pour le dossier : N=4  ->  //p'
ligne V4 "Durée de la procédure de bascule" v4_panne_bdd_ 's/^Durée de la procédure de bascule (lancement -> service rétabli) : \(.*\)   <- mesure V4/\1/p'
ligne V5 "Durée de la reconstruction intégrale" v5_reconstruction_ 's/^Durée de reconstruction (mesure V5) : //p'
ligne V6 "Interruption maximale du service" v6_panne_lb_ 's/^Interruption maximale : \([^,]*\),.*/\1/p'
ligne R2 "Idempotence du provisionnement" r2_idempotence_ 's/^RÉSULTAT : //p'

echo
echo "## Verdicts"
echo
echo "| Essai | Verdict | Sortie brute |"
echo "| --- | --- | --- |"
for prefixe in v1_repartition_ v2_panne_app_ v3_charge_ v4_panne_bdd_ v5_reconstruction_ v6_panne_lb_ r2_idempotence_; do
    while read -r f; do
        [ -z "$f" ] && continue
        v="$(valeur "$f" 's/^RÉSULTAT : //p')"
        [ -z "$v" ] && v="*(essai interrompu)*"
        printf '| %s | %s | `%s` |\n' "${prefixe%_}" "$v" "$(basename "$f")"
    done < <(fichiers "$prefixe")
done

echo
echo "> Les lignes « à mesurer » correspondent à des scénarios dont aucune"
echo "> sortie n'existe encore dans \`$DOSSIER\`. Les lancer avant le rendu :"
echo "> voir le tableau des essais du README."
