#!/usr/bin/env bash
# Fonctions communes à tous les scripts de provisionnement.
#
# Usage, en tête de chaque script de rôle (bdd.sh, app.sh, lb.sh…) :
#
#     source /vagrant/scripts/commun.sh
#     charger_env
#     installer_paquets postgresql-16 curl
#
# Règle du projet : chaque fonction est idempotente. Rejouer
# « vagrant provision » deux fois de suite ne doit rien changer (R2).

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

RACINE_PROJET="${RACINE_PROJET:-/vagrant}"
NOEUDS_YML="${NOEUDS_YML:-$RACINE_PROJET/config/noeuds.yml}"
ETAT_DIR="/var/lib/resultats-bf"

journal() {
    printf '[%s] %s\n' "$(hostname)" "$*"
}

erreur() {
    printf '[%s] ERREUR : %s\n' "$(hostname)" "$*" >&2
    exit 1
}

# Charge les secrets de $RACINE_PROJET/.env dans l'environnement (R7).
# Échoue tout de suite, avec un message clair, si le fichier manque.
charger_env() {
    local fichier="$RACINE_PROJET/.env"
    [ -f "$fichier" ] || erreur "$fichier introuvable : lancer « cp .env.exemple .env » sur l'hôte puis le compléter."
    set -a
    # shellcheck disable=SC1090
    . <(tr -d '\r' < "$fichier")
    set +a
    if grep -q '=a_changer$' <(tr -d '\r' < "$fichier"); then
        journal "ATTENTION : des valeurs « a_changer » restent dans .env."
    fi
}

# Installe en un seul appel apt les paquets manquants de la liste.
# « apt-get update » n'est lancé que si l'index a plus de 6 heures :
# le provisionnement doit rester rapide derrière une connexion lente.
installer_paquets() {
    local manquants=() p
    for p in "$@"; do
        dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' || manquants+=("$p")
    done
    [ "${#manquants[@]}" -eq 0 ] && return 0

    mkdir -p "$ETAT_DIR"
    local tampon="$ETAT_DIR/apt-update"
    if [ ! -f "$tampon" ] || [ -n "$(find "$tampon" -mmin +360)" ]; then
        journal "apt-get update"
        apt-get update -qq
        touch "$tampon"
    fi
    journal "installation : ${manquants[*]}"
    apt-get install -y -qq --no-install-recommends "${manquants[@]}"
}

# Écrit l'entrée standard dans <destination> seulement si le contenu diffère.
# Code retour : 0 si le fichier a changé, 1 s'il était déjà à jour.
# Permet de ne redémarrer un service que lorsque sa configuration change :
#
#     if ecrire_si_different /etc/haproxy/haproxy.cfg <<EOF
#     ...
#     EOF
#     then systemctl reload haproxy; fi
ecrire_si_different() {
    local destination="$1" mode="${2:-0644}" tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    if [ -f "$destination" ] && cmp -s "$tmp" "$destination"; then
        rm -f "$tmp"
        return 1
    fi
    mkdir -p "$(dirname "$destination")"
    install -m "$mode" "$tmp" "$destination"
    rm -f "$tmp"
    journal "écrit : $destination"
    return 0
}

# Ajoute <ligne> à <fichier> seulement si elle n'y est pas déjà.
# À utiliser à la place de « echo ... >> fichier », qui accumule les doublons.
ajouter_ligne() {
    local fichier="$1" ligne="$2"
    touch "$fichier"
    grep -qxF -- "$ligne" "$fichier" || printf '%s\n' "$ligne" >> "$fichier"
}

# Lit config/noeuds.yml (engendré par le Vagrantfile) et affiche
# « nom ip » pour chaque machine du rôle demandé, une par ligne.
# Rôle vide ("") : toutes les machines.
# Accepte les clés Ruby en symboles (« :nom: ») comme en texte (« nom: »).
#
#     noeuds_par_role app   ->   app1 192.168.61.21
#                                app2 192.168.61.22
noeuds_par_role() {
    local role="$1"
    [ -f "$NOEUDS_YML" ] || erreur "$NOEUDS_YML introuvable : il est engendré par le Vagrantfile."
    tr -d '\r' < "$NOEUDS_YML" | awk -v voulu="$role" '
        function emettre() { if (nom != "" && (voulu == "" || r == voulu)) print nom, ip; nom = ip = r = "" }
        /^-/        { emettre(); sub(/^-[ ]*/, "") }
        {
            ligne = $0
            sub(/^[ ]+/, "", ligne); sub(/^:/, "", ligne)
            i = index(ligne, ":"); if (i == 0) next
            cle = substr(ligne, 1, i - 1)
            val = substr(ligne, i + 1); gsub(/^[ ]+|[ ]+$|["\047]/, "", val)
            if (cle == "nom") nom = val
            else if (cle == "ip") ip = val
            else if (cle == "role") r = val
        }
        END         { emettre() }'
}

# Affiche l'adresse IP de la machine <nom> (ex. : ip_de bdd1).
ip_de() {
    local nom="$1" ip
    ip="$(noeuds_par_role "" | awk -v n="$nom" '$1 == n { print $2; exit }')"
    [ -n "$ip" ] || erreur "machine « $nom » absente de $NOEUDS_YML"
    printf '%s\n' "$ip"
}

# Attend qu'un port TCP réponde, au plus <délai> secondes (60 par défaut).
# Sert à respecter l'ordre de démarrage : la base avant les applications.
attendre_port() {
    local hote="$1" port="$2" delai="${3:-60}" t=0
    until (exec 3<>"/dev/tcp/$hote/$port") 2>/dev/null; do
        t=$((t + 1))
        [ "$t" -ge "$delai" ] && erreur "$hote:$port injoignable après ${delai}s"
        sleep 1
    done
    journal "$hote:$port joignable"
}

# Installe node_exporter (métriques système : processeur, mémoire, disque,
# réseau) et vérifie qu'il répond sur le port 9100. La machine obs
# (extension E2) vient y lire les métriques de chaque machine.
# Appelée pour toutes les machines par le Vagrantfile, avant le script de
# rôle : les scripts de rôle n'ont rien à ajouter.
installer_node_exporter() {
    installer_paquets prometheus-node-exporter
    systemctl enable --quiet --now prometheus-node-exporter
    attendre_port 127.0.0.1 9100 30
}
