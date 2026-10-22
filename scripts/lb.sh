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
# - Quand tous les serveurs sont écartés, HAProxy répond un 503 en JSON,
#   comme l'application, au lieu de sa page HTML par défaut (V4).
# - Extension E1 (EXT=e1, lb2 déclarée) : keepalived porte l'IP virtuelle
#   .10 sur lb1 ; si lb1 tombe ou si HAProxy n'y répond plus, lb2 la reprend.
source /vagrant/scripts/commun.sh
charger_env
PORT_APP=8000          # port de l'application (CONTRATS.md)
CONF=/etc/haproxy/haproxy.cfg

# E1 active si au moins deux répartiteurs sont déclarés dans noeuds.yml
REPARTITEURS="$(noeuds_par_role lb)"
NB_LB="$(printf '%s\n' "$REPARTITEURS" | grep -c .)"

if [ "$NB_LB" -ge 2 ]; then
    installer_paquets haproxy keepalived curl
else
    installer_paquets haproxy curl
fi

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
    # Erreurs produites par HAProxy lui-même : JSON, comme l'application
    http-error status 502 content-type "application/json; charset=utf-8" string '{"erreur":"service indisponible","source":"repartiteur"}'
    http-error status 503 content-type "application/json; charset=utf-8" string '{"erreur":"service indisponible","source":"repartiteur"}'
    http-error status 504 content-type "application/json; charset=utf-8" string '{"erreur":"service indisponible","source":"repartiteur"}'

frontend entree_web
    bind *:80
    default_backend serveurs_app

backend serveurs_app
    balance roundrobin
    option httpchk GET /sante
    http-check expect status 200
    default-server inter 1s fall 2 rise 2
$(lignes_serveurs)

# Métriques pour Prometheus (extension E2) et page de statistiques.
# Port interne au réseau privé : non redirigé vers l'hôte (R8).
frontend statistiques
    bind *:8404
    http-request use-service prometheus-exporter if { path /metrics }
    stats enable
    stats uri /stats
    stats refresh 5s
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

# ---------------------------------------------------------------------------
# Extension E1 : IP virtuelle partagée entre les répartiteurs (VRRP)
# ---------------------------------------------------------------------------
if [ "$NB_LB" -lt 2 ]; then
    # Sans lb2, pas de VRRP : on arrête keepalived s'il reste d'une session E1
    if systemctl is-enabled --quiet keepalived 2>/dev/null; then
        systemctl disable --now --quiet keepalived
        journal "E1 inactive (une seule machine lb) : keepalived arrêté"
    fi
    exit 0
fi

[ -n "${KEEPALIVED_MOT_DE_PASSE:-}" ] || erreur "KEEPALIVED_MOT_DE_PASSE absent de .env (voir .env.exemple)"

MOI="$(hostname)"
MON_IP="$(ip_de "$MOI")"
VIP="${MON_IP%.*}.10"                       # .10 du sous-réseau du groupe
VRID="$(echo "$MON_IP" | cut -d. -f3)"      # 61 pour le groupe 6
INTERFACE="$(ip -o -4 addr show | awk -v ip="$MON_IP" '{ split($4, a, "/") } a[1] == ip { print $2; exit }')"
[ -n "$INTERFACE" ] || erreur "aucune interface ne porte $MON_IP"

# Le premier répartiteur de la table (lb1) est le maître ; les autres attendent
PREMIER="$(printf '%s\n' "$REPARTITEURS" | awk 'NR == 1 { print $1 }')"
if [ "$MOI" = "$PREMIER" ]; then ETAT=MASTER; PRIORITE=150; else ETAT=BACKUP; PRIORITE=100; fi
PAIRS="$(printf '%s\n' "$REPARTITEURS" | awk -v moi="$MOI" '$1 != moi { print "        " $2 }')"

# Sonde écrite par KUELA : HAProxy répond-il sur le port 80 ?
SONDE_CHANGEE=1
if ecrire_si_different /usr/local/bin/verifier_haproxy 0755 < /vagrant/config/keepalived/verifier_haproxy.sh; then
    SONDE_CHANGEE=0
fi

if ecrire_si_different /etc/keepalived/keepalived.conf 0600 <<KCONF || [ "$SONDE_CHANGEE" -eq 0 ]; then
# Fichier engendré par scripts/lb.sh : ne pas modifier à la main.
global_defs {
    router_id $MOI
    enable_script_security
    script_user root
}

vrrp_script verifier_haproxy {
    script "/usr/local/bin/verifier_haproxy"
    interval 1      # une vérification par seconde
    timeout 2
    fall 2          # 2 échecs : l'IP virtuelle part (cible V6 < 5 s)
    rise 2
}

vrrp_instance VI_RESULTATS {
    state $ETAT
    interface $INTERFACE
    virtual_router_id $VRID
    priority $PRIORITE
    advert_int 1
    # Unicast : plus fiable que la multidiffusion sur un réseau VirtualBox
    unicast_src_ip $MON_IP
    unicast_peer {
$PAIRS
    }
    authentication {
        auth_type PASS
        auth_pass ${KEEPALIVED_MOT_DE_PASSE:0:8}
    }
    virtual_ipaddress {
        $VIP/24 dev $INTERFACE
    }
    track_script {
        verifier_haproxy
    }
}
KCONF
    systemctl enable --quiet keepalived
    systemctl reload-or-restart keepalived
    journal "keepalived ($ETAT, priorité $PRIORITE) : IP virtuelle $VIP sur $INTERFACE"
else
    journal "configuration keepalived inchangée, pas de rechargement"
fi

systemctl is-active --quiet keepalived || systemctl start keepalived
