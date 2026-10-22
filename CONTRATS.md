# Conventions entre membres — Groupe 6

Ces conventions permettent à chacun de travailler en parallèle sans attendre
les autres. **Personne ne les change seul** : une modification se décide au
point du matin et se note dans `JOURNAL.md`.

Statut : proposées le 2026-10-19, à valider par le groupe.

## Machines et scripts

| Sujet | Convention |
| --- | --- |
| Boîte | `bento/ubuntu-24.04`, version `202510.26.0` (la `202404.23.0` du sujet n'est pas publiée sur Vagrant Cloud) |
| Rôles dans la table `NOEUDS` | `bdd`, `replique`, `app`, `lb`, `obs` → un script `scripts/<rôle>.sh` par rôle |
| Début de chaque script de rôle | `source /vagrant/scripts/commun.sh` puis `charger_env` |
| Adresses IP | Lues avec `noeuds_par_role <rôle>` ou `ip_de <machine>`, **jamais écrites en dur** |
| Écriture de fichiers | `ecrire_si_different` et `ajouter_ligne`, jamais `>>` directement (R2) |
| Installation de paquets | `installer_paquets`, un seul appel groupé par script |

## Base de données

| Sujet | Convention |
| --- | --- |
| Table | `resultats(matricule TEXT PRIMARY KEY, nom TEXT, serie TEXT, moyenne NUMERIC(4,2), admis BOOLEAN)`, 50 000 lignes |
| Port | 5432, écoute sur le réseau privé 192.168.61.0/24 |
| Identifiants | Variables `BDD_NOM`, `BDD_UTILISATEUR`, `BDD_MOT_DE_PASSE` de `.env` |
| Réplication | Variables `BDD_REPLICATION_UTILISATEUR`, `BDD_REPLICATION_MOT_DE_PASSE` de `.env` |

## Application

| Sujet | Convention |
| --- | --- |
| Port | 8000, écoute sur `0.0.0.0` (jamais `127.0.0.1`) |
| Adresse de la base | Variable `BDD_HOTE` dans `/etc/resultats-app/bdd_hote.env`, écrite une seule fois par `scripts/app.sh` (`ip_de bdd1`), puis **relue à chaque requête** par l'application |
| Bascule de la base | `scripts/bascule.sh` réécrit `BDD_HOTE` dans ce fichier sur chaque serveur applicatif, **sans redémarrer** `resultats-app` |
| `GET /resultat?matricule=…` | Route imposée par le sujet : JSON du candidat, 404 si inconnu, 400 sans matricule, 503 si la base est indisponible |
| `GET /sante` | 200 si `SELECT 1` réussit sur la base, 503 sinon ; jamais 200 « par principe » ; jamais le texte brut d'une erreur de la base |
| `GET /info` | Renvoie le nom d'hôte de la machine qui répond |
| Service systemd | `resultats-app` |

## Accès et essais

| Sujet | Convention |
| --- | --- |
| Adresse depuis l'hôte | `http://localhost:8080` (seul port exposé, par lb1, R8) |
| Adresse virtuelle (E1) | `http://192.168.61.10` — à utiliser pour V6, où lb1 est arrêté |
| Sorties des essais | Un fichier horodaté par exécution dans `essais/resultats/`, versionné |
| Variables d'environnement | Garder les mêmes `NB_APP` et `EXT` pendant toute une session, y compris pour `vagrant destroy` |
