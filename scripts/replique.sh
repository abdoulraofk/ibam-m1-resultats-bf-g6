#!/usr/bin/env bash
# Rôle replique : PostgreSQL réplique (bdd2) - KAGAMBEGA
# Idempotent (R2) : la copie initiale n'est faite qu'une fois.
source /vagrant/scripts/commun.sh
charger_env
installer_paquets postgresql-16
PG_VERSION=16
PG_ETC="/etc/postgresql/${PG_VERSION}/main"
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
SERVICE="postgresql@${PG_VERSION}-main"
IP_BDD1="$(ip_de bdd1)"
IP_BDD2="$(ip_de bdd2)"
RESEAU="${IP_BDD2%.*}.0/24"
CHANGE=0
# --- Configuration réseau (lecture seule tant que bdd2 est réplique) --
if ecrire_si_different "${PG_ETC}/conf.d/resultats.conf" <<CONF
listen_addresses = '127.0.0.1,${IP_BDD2}'
port = 5432
hot_standby = on
CONF
then CHANGE=1; fi
# Mêmes accès que bdd1 : utiles si bdd2 est promue lors de la bascule
ajouter_ligne "${PG_ETC}/pg_hba.conf" "host ${BDD_NOM} ${BDD_UTILISATEUR} ${RESEAU} scram-sha-256"
ajouter_ligne "${PG_ETC}/pg_hba.conf" "host replication ${BDD_REPLICATION_UTILISATEUR} ${RESEAU} scram-sha-256"
# --- Copie initiale depuis bdd1, UNE SEULE FOIS dans la vie de la VM ---
# Le marqueur survit aux "vagrant provision" mais pas à "vagrant destroy".
# Après une bascule, bdd2 est promue : il ne faut plus jamais la recopier.
MARQUEUR="${ETAT_DIR}/replique-initialisee"
if [ ! -f "$MARQUEUR" ]; then
  journal "attente de bdd1 (${IP_BDD1}:5432)"
  attendre_port "${IP_BDD1}" 5432

  systemctl stop "${SERVICE}"
  find "${PG_DATA}" -mindepth 1 -delete

  journal "copie de bdd1 vers bdd2 (pg_basebackup)"
  sudo -u postgres env PGPASSWORD="${BDD_REPLICATION_MOT_DE_PASSE}" \
    pg_basebackup -h "${IP_BDD1}" -U "${BDD_REPLICATION_UTILISATEUR}" \
    -D "${PG_DATA}" -X stream -R

  mkdir -p "${ETAT_DIR}" && touch "$MARQUEUR"
  CHANGE=1
fi
if [ "$CHANGE" = 1 ]; then
  systemctl restart "${SERVICE}"
else
  systemctl reload "${SERVICE}"
fi
attendre_port 127.0.0.1 5432
if [ "$(sudo -u postgres psql -Atc 'SELECT pg_is_in_recovery();')" = "t" ]; then
  journal "rôle replique : bdd2 réplique bdd1"
else
  journal "rôle replique : bdd2 est primaire (bascule effectuée)"
fi
