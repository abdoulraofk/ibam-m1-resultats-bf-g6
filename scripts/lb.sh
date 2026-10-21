#!/usr/bin/env bash
# Rôle lb : répartiteur de charge HAProxy devant les serveurs applicatifs.
# Responsable : SIMPORE
#
# - La liste des serveurs est lue dans config/noeuds.yml (noeuds_par_role app) :
#   aucune adresse IP n'est écrite en dur. Avec NB_APP=4, app3 et app4 sont
#   ajoutés automatiquement au prochain « vagrant provision lb1 » (R3).
# - Un serveur est retiré dès que GET /sante échoue 2 fois de suite
#   (une sonde par seconde), et réintégré après 2 réponses 200.
# - Ce script est rejoué à chaque « vagrant up / provision » (run: always).
#   HAProxy n'est rechargé que si sa configuration a changé (R2).
source /vagrant/scripts/commun.sh
charger_env
installer_paquets haproxy

PORT_APP=8000          # port de l'application (CONTRATS.md)
CONF=/etc/haproxy/haproxy.cfg

SERVEURS="$(noeuds_par_role app)"
[ -n "$SERVEURS" ] || erreur "aucune machine de rôle app dans $NOEUDS_YML"

lignes_serveurs() {
    local nom ip
    while read -r nom ip; do
        printf '    server %s %s:%s check\n' "$nom" "$ip" "$PORT_APP"
    done <<< "$SERVEURS"
}

# 1. Engendrer la configuration dans un fichier temporaire
NOUVELLE="$(mktemp)"
trap 'rm -f "$NOUVELLE"' EXIT
cat > "$NOUVELLE" <<CFG
# Fichier engendré par scripts/lb.sh : ne pas modifier à la main.
global
    log /dev/log local0
    user haproxy
    group haproxy
    daemon
    maxconn 2000
    stats socket /run/haproxy/admin.sock mode 660 level admin

defaults
    mode http
    log global
    option httplog
    option dontlognull
    option forwardfor
    option redispatch
    retries 2
    # Une requête GET restée sans réponse (serveur tombé pendant la requête)
    # est rejouée sur un autre serveur au lieu d'être perdue (R4, V2).
    retry-on conn-failure empty-response response-timeout
    timeout connect 2s
    timeout client 30s
    timeout server 5s

frontend entree_web
    bind *:80
    default_backend serveurs_app

backend serveurs_app
    balance roundrobin
    option httpchk GET /sante
    http-check expect status 200
    default-server inter 1s fall 2 rise 2
$(lignes_serveurs)
CFG

# 2. Vérifier la syntaxe AVANT de remplacer la configuration en service
haproxy -c -q -f "$NOUVELLE" || erreur "configuration HAProxy invalide, rien n'a été remplacé"

# 3. Remplacer et recharger seulement si quelque chose a changé
if ecrire_si_different "$CONF" < "$NOUVELLE"; then
    systemctl enable --quiet haproxy
    systemctl reload-or-restart haproxy
    journal "HAProxy rechargé avec : $(echo $SERVEURS)"
else
    journal "configuration HAProxy inchangée, pas de rechargement"
fi

systemctl is-active --quiet haproxy || systemctl start haproxy
