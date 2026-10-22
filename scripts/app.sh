#!/usr/bin/env bash
# Rôle « app » : installe l'application RÉSULTATS-BF (Flask + gunicorn)
# et la lance en service systemd « resultats-app » sur le port 8000.
# Idempotent (R2) : un second passage ne modifie aucun fichier.

source /vagrant/scripts/commun.sh
charger_env

installer_paquets python3-flask python3-psycopg2 gunicorn

# Utilisateur système dédié : l'application ne tourne pas en root
if ! id -u resultats >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin resultats
fi

redemarrer=non

# 1. Code de l'application
if ecrire_si_different /opt/resultats-app/app.py 0644 < "$RACINE_PROJET/app/app.py"; then
    redemarrer=oui
fi

# 2. Identifiants de la base (contiennent le mot de passe : 0640)
if ecrire_si_different /etc/resultats-app/app.env 0640 <<EOF
BDD_NOM=$BDD_NOM
BDD_UTILISATEUR=$BDD_UTILISATEUR
BDD_MOT_DE_PASSE=$BDD_MOT_DE_PASSE
EOF
then
    redemarrer=oui
fi

# 3. Adresse de la base : écrite une seule fois, ensuite la bascule s'en charge
if [ ! -f /etc/resultats-app/bdd_hote.env ]; then
    ecrire_si_different /etc/resultats-app/bdd_hote.env 0640 <<EOF || true
BDD_HOTE=$(ip_de bdd1)
EOF
    redemarrer=oui
fi
chgrp resultats /etc/resultats-app/app.env /etc/resultats-app/bdd_hote.env

# 4. Service systemd
if ecrire_si_different /etc/systemd/system/resultats-app.service <<'EOF'
[Unit]
Description=Application RESULTATS-BF
After=network-online.target
Wants=network-online.target

[Service]
User=resultats
Group=resultats
WorkingDirectory=/opt/resultats-app
ExecStart=/usr/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 --access-logfile - app:app
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
then
    systemctl daemon-reload
    redemarrer=oui
fi

# 5. Pas d'attente de la base : l'application démarre sans elle et se
#    connecte à chaque requête (/sante répond 503 tant qu'elle est absente).
#    Après une bascule, bdd1 est arrêtée : l'attendre ferait échouer le
#    provisionnement.

systemctl enable --quiet resultats-app
if [ "$redemarrer" = oui ]; then
    systemctl restart resultats-app
else
    systemctl start resultats-app
fi
attendre_port 127.0.0.1 8000 30
journal "resultats-app prête sur le port 8000"