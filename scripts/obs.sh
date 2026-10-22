#!/usr/bin/env bash
# Rôle obs (extension E2) : Prometheus + Grafana.
# Responsable : NIKIEMA — version initiale écrite par KUELA le 22/10 pour
# tenir le planning.
#
# - Prometheus lit, toutes les 5 s, node_exporter (port 9100) sur chaque
#   machine et l'exportateur intégré de HAProxy (port 8404) sur lb1 / lb2.
#   Les cibles sont engendrées depuis config/noeuds.yml : avec NB_APP=4,
#   un « vagrant provision obs » suffit pour suivre app3 et app4.
# - Grafana affiche le tableau de bord config/grafana/resultats-bf.json :
#   débit par serveur, serveurs en service, erreurs, processeur.
#   Accès depuis l'hôte, par le réseau privé : http://<ip de obs>:3000
#   (lecture sans compte ; admin / GRAFANA_ADMIN_MOT_DE_PASSE de .env).
source /vagrant/scripts/commun.sh
charger_env

# --- Dépôt Grafana (Grafana n'est pas dans les dépôts Ubuntu) -------------
installer_paquets ca-certificates curl gnupg
if [ ! -s /etc/apt/keyrings/grafana.gpg ]; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg
fi
if ecrire_si_different /etc/apt/sources.list.d/grafana.list <<EOF
deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main
EOF
then
    rm -f "$ETAT_DIR/apt-update"   # forcer la lecture du nouveau dépôt
fi
installer_paquets prometheus grafana

# --- Prometheus : cibles engendrées depuis noeuds.yml ----------------------
cibles_node() {
    local role nom ip
    for role in bdd replique app lb obs; do
        while read -r nom ip; do
            [ -n "$nom" ] || continue
            printf "      - targets: ['%s:9100']\n        labels: {machine: %s, role: %s}\n" "$ip" "$nom" "$role"
        done < <(noeuds_par_role "$role")
    done
}
cibles_haproxy() {
    local nom ip
    while read -r nom ip; do
        [ -n "$nom" ] || continue
        printf "      - targets: ['%s:8404']\n        labels: {machine: %s}\n" "$ip" "$nom"
    done < <(noeuds_par_role lb)
}

redemarrer_prometheus=non
if ecrire_si_different /etc/prometheus/prometheus.yml <<EOF
# Fichier engendré par scripts/obs.sh depuis config/noeuds.yml : ne pas modifier.
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: node
    static_configs:
$(cibles_node)

  - job_name: haproxy
    metrics_path: /metrics
    static_configs:
$(cibles_haproxy)
EOF
then
    redemarrer_prometheus=oui
fi
# Six heures d'historique suffisent et ménagent les 768 Mo de la machine
if ecrire_si_different /etc/default/prometheus <<'EOF'
ARGS="--storage.tsdb.retention.time=6h"
EOF
then
    redemarrer_prometheus=oui
fi
promtool check config /etc/prometheus/prometheus.yml >/dev/null \
    || erreur "configuration Prometheus invalide"

# --- Grafana : source de données, tableau de bord, secrets ----------------
redemarrer_grafana=non
if ecrire_si_different /etc/grafana/provisioning/datasources/resultats.yaml <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF
then redemarrer_grafana=oui; fi

if ecrire_si_different /etc/grafana/provisioning/dashboards/resultats.yaml <<'EOF'
apiVersion: 1
providers:
  - name: resultats-bf
    type: file
    options:
      path: /var/lib/grafana/dashboards
EOF
then redemarrer_grafana=oui; fi

if ecrire_si_different /var/lib/grafana/dashboards/resultats-bf.json < "$RACINE_PROJET/config/grafana/resultats-bf.json"; then
    redemarrer_grafana=oui
fi

# Mot de passe administrateur lu dans .env (appliqué à la création de la
# base de Grafana) ; consultation sans compte pour la démonstration.
if ecrire_si_different /etc/grafana/resultats.env 0640 <<EOF
GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_MOT_DE_PASSE
GF_AUTH_ANONYMOUS_ENABLED=true
GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/resultats-bf.json
GF_ANALYTICS_REPORTING_ENABLED=false
GF_ANALYTICS_CHECK_FOR_UPDATES=false
EOF
then redemarrer_grafana=oui; fi
chgrp grafana /etc/grafana/resultats.env

if ecrire_si_different /etc/systemd/system/grafana-server.service.d/resultats.conf <<'EOF'
[Service]
EnvironmentFile=/etc/grafana/resultats.env
EOF
then
    systemctl daemon-reload
    redemarrer_grafana=oui
fi

# --- Démarrage ------------------------------------------------------------
systemctl enable --quiet prometheus grafana-server
if [ "$redemarrer_prometheus" = oui ]; then systemctl restart prometheus; else systemctl start prometheus; fi
if [ "$redemarrer_grafana" = oui ]; then systemctl restart grafana-server; else systemctl start grafana-server; fi
attendre_port 127.0.0.1 9090 60
attendre_port 127.0.0.1 3000 120
journal "obs prête : Prometheus :9090, Grafana http://$(ip_de obs):3000"
