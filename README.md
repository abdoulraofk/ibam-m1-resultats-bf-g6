# RÉSULTATS-BF — Groupe 6

Plateforme de consultation des résultats d'examen par matricule, construite
pour **résister à la panne d'une machine** et **monter en charge en ajoutant
des serveurs**. Toute l'infrastructure est décrite en code (Vagrant +
VirtualBox) et se reconstruit sans aucun geste manuel.

Projet de groupe — M1 Informatique, IBAM / Université Joseph KI-ZERBO,
Virtualisation et Cloud Computing (Dr SOMDA), 2026-2027.

> README en cours de rédaction : la procédure complète (scénarios V1 à V6,
> bascule de la base, ajout d'un serveur) sera complétée au fil de la semaine.

## Démarrage rapide

Prérequis : VirtualBox 7, Vagrant 2.4, Git, 8 Go de RAM.

```bash
git clone https://github.com/abdoulraofk/ibam-m1-resultats-bf-g6.git
cd ibam-m1-resultats-bf-g6
cp .env.exemple .env        # puis remplacer chaque « a_changer »
vagrant up
```

Le service répond ensuite sur <http://localhost:8080/info>.

Pour changer le nombre de serveurs applicatifs : `NB_APP=4 vagrant up`.

## Architecture

Sous-réseau privé du groupe 6 : **192.168.61.0/24**.

| Machine | Rôle | Adresse | RAM |
| --- | --- | --- | --- |
| bdd1 | PostgreSQL primaire | 192.168.61.31 | 768 Mo |
| bdd2 | Réplique en flux, promouvable | 192.168.61.32 | 768 Mo |
| app1 … appN | Serveurs applicatifs sans état | 192.168.61.21 … | 512 Mo |
| lb1 | Répartiteur HAProxy actif | 192.168.61.11 | 512 Mo |
| lb2 | Répartiteur passif, IP virtuelle .10 (E1) | 192.168.61.12 | 512 Mo |
| obs | Prometheus + Grafana (E2) | 192.168.61.41 | 768 Mo |

La table `NOEUDS` du `Vagrantfile` est la **source unique de vérité** : elle
crée les machines et produit `config/noeuds.yml`, d'où la configuration du
répartiteur est engendrée. Aucune adresse n'est écrite en dur ailleurs.

## Arborescence

| Chemin | Contenu |
| --- | --- |
| `Vagrantfile` | Définition des machines (table `NOEUDS`) |
| `scripts/` | Provisionnement : `commun.sh` + un script par rôle |
| `app/` | Service HTTP (`/resultat`, `/sante`, `/info`) |
| `config/` | Fichiers de configuration ; `noeuds.yml` y est engendré |
| `essais/` | Un script par scénario de validation ; sorties brutes dans `essais/resultats/` |
| `CONTRATS.md` | Conventions entre membres : ports, noms, schéma de la table |
| `JOURNAL.md` | Journal de bord : décisions, difficultés |

## Contrôler la plateforme et la reconstruire (R1, V5)

Après un `vagrant up`, depuis la racine du dépôt :

```bash
essais/controle_socle.sh        # machines, base, réplique, service, répartition
essais/v5_reconstruction.sh     # destroy -f + up chronométré, puis contrôle
```

**Sous Windows, depuis PowerShell**, passer par le lanceur :

```powershell
essais\lancer.cmd controle_socle
essais\lancer.cmd v5_reconstruction
essais\lancer.cmd r2_idempotence
```

Ne pas taper `bash essais/...` dans PowerShell : `bash` y lance WSL, où
Vagrant ne voit pas les VM de Windows. Ne pas lancer non plus le `.sh`
directement : il s'ouvre dans une fenêtre qui se ferme aussitôt.

Chaque point est affiché OK ou KO, et le script se termine en erreur s'il y a
un KO. C'est la vérification de la reconstruction croisée du soir.
`v5_reconstruction.sh` **détruit les machines** : le lancer avec les mêmes
`NB_APP` / `EXT` que lors de la création.

## Vérifier l'idempotence (R2)

Plateforme démarrée, depuis la racine du dépôt :

```bash
essais/r2_idempotence.sh            # toutes les machines en marche
essais/r2_idempotence.sh bdd1 app1  # machines choisies
```

Le script rejoue `vagrant provision` deux fois et compare l'empreinte de
chaque fichier de `/etc` entre les deux passes. Il se termine en erreur si la
seconde passe a modifié quoi que ce soit ; la sortie brute est écrite dans
`essais/resultats/`.

## Règles de contribution

- **Secrets** : jamais dans un fichier versionné. Ils vivent dans `.env`
  (ignoré par Git) ; `.env.exemple` en donne la liste.
- **Fins de ligne** : LF partout, imposé par `.gitattributes`. Sous Windows,
  ne pas modifier ce réglage dans l'éditeur.
- **Idempotence** : dans les scripts, utiliser les fonctions de
  `scripts/commun.sh` (`installer_paquets`, `ecrire_si_different`,
  `ajouter_ligne`) plutôt que `apt-get` ou `>>` directement. Rejouer
  `vagrant provision` deux fois avant de pousser.
- **Branches** : une branche par tâche, fusion dans `main` seulement si
  `vagrant up` passe.
- **Services réseau** : écouter sur `0.0.0.0`, jamais `127.0.0.1`.

## Équipe

| Membre | Rôle |
| --- | --- |
| SIMPORE Wend-Yam Lysias Eldad | Architecte réseau et répartition |
| OUEDRAOGO D. Adan Franck | Ingénieur applicatif |
| KAGAMBEGA Hermann | Ingénieur données |
| NIKIEMA Shun Arion | Ingénieur essais et observabilité |
| KUELA Abdoul Raof | Intégration, reproductibilité et documentation |
