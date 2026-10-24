# RÉSULTATS-BF — Groupe 6

Plateforme de consultation des résultats d'examen par matricule, construite
pour **résister à la panne d'une machine** et **monter en charge en ajoutant
des serveurs**. Toute l'infrastructure est décrite en code (Vagrant +
VirtualBox) et se reconstruit sans aucun geste manuel.

Projet de groupe — M1 Informatique, IBAM / Université Joseph KI-ZERBO,
Virtualisation et Cloud Computing (Dr SOMDA), 2026-2027.

## Prérequis

| Outil | Version testée | Remarque |
| --- | --- | --- |
| VirtualBox | 7.2 | |
| Vagrant | 2.4.9 | |
| Git | récente | Sous Windows : Git for Windows, qui fournit Git Bash |
| Mémoire | 8 Go | Le socle utilise 3 Go : il faut **3 Go libres** avant `vagrant up` |

Sous Windows, Docker Desktop et WSL réservent souvent 2 à 3 Go : les fermer
pendant les essais si la mémoire libre est insuffisante.

## Démarrage

```bash
git clone https://github.com/abdoulraofk/ibam-m1-resultats-bf-g6.git
cd ibam-m1-resultats-bf-g6
cp .env.exemple .env        # PowerShell : Copy-Item .env.exemple .env
                            # puis remplacer chaque « a_changer »
vagrant up
```

Le premier `vagrant up` télécharge la boîte `bento/ubuntu-24.04` (environ
1 Go), puis crée et provisionne les machines. Le service répond ensuite sur
<http://localhost:8080/info>.

Vérifier que tout est en place :

```bash
essais/controle_socle.sh             # Git Bash
essais\lancer.cmd controle_socle     # PowerShell
```

## Variables

| Variable | Défaut | Effet |
| --- | --- | --- |
| `NB_APP` | 2 | Nombre de serveurs applicatifs (2 à 9) |
| `EXT` | vide | Extensions à démarrer : `e1` (lb2), `e1,e2` (lb2 + obs) |
| `GROUPE` | 6 | Numéro de groupe, fixe le sous-réseau 192.168.(55+G).0/24 |

```bash
NB_APP=4 vagrant up                  # Git Bash
$env:NB_APP=4; vagrant up            # PowerShell
```

**Garder les mêmes variables pendant toute la session**, y compris pour
`vagrant destroy` : après `NB_APP=4`, un `vagrant destroy -f` sans la variable
laisse app3 et app4 allumées hors du contrôle de Vagrant.

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

Chemin d'une requête :

```
hôte :8080 ──► lb1 :80 (HAProxy) ──► app1…appN :8000 ──► bdd1 :5432 ──réplication──► bdd2
                     sonde GET /sante chaque seconde          node_exporter :9100 sur chaque VM ──► obs
```

- La table `NOEUDS` du `Vagrantfile` est la **source unique de vérité** :
  elle crée les machines et produit `config/noeuds.yml`, d'où la
  configuration HAProxy est engendrée. Aucune adresse n'est écrite en dur
  ailleurs (R3).
- Seul lb1 expose un port vers l'hôte (8080 → 80, sur 127.0.0.1) : tout le
  reste passe par le réseau privé (R8).
- HAProxy écarte un serveur après 2 échecs de `/sante` à une seconde
  d'intervalle (R4), et rejoue sur un autre serveur une requête restée sans
  réponse plus de 5 s.
- Les secrets sont dans `.env`, jamais versionné (R7). Les conventions entre
  composants (ports, schéma de la table, noms) sont dans `CONTRATS.md`.

## Essais et scénarios de validation

Sous PowerShell, remplacer `essais/xxx.sh` par `essais\lancer.cmd xxx`.
Chaque essai écrit sa sortie brute horodatée dans `essais/resultats/`.

| Exigence / scénario | Commande | Ce qui est vérifié |
| --- | --- | --- |
| Contrôle général | `essais/controle_socle.sh` | Machines, 50 000 lignes, réplique, `/sante`, `/resultat`, répartition |
| V1 — Répartition | `essais/v1_repartition.sh [appels]` | 20 appels à `/info` ; écart (max − min) / moyenne < 20 % |
| V2 — Panne d'une app | `essais/v2_panne_app.sh [app1] [durée]` | `vagrant halt app1` sous charge : requêtes perdues, période dégradée, rien au-delà de 5 s |
| V3 — Montée en charge | `essais/v3_charge.sh [passes]` | `ab -n 2000 -c 50` ; à lancer avec `NB_APP=2` puis `NB_APP=4` ; débit médian |
| V4 — Panne de la base | `essais/v4_panne_bdd.sh` | `vagrant halt bdd1` : 503 propre, puis `scripts/bascule.sh` chronométré |
| R1 / V5 — Reconstruction | `essais/v5_reconstruction.sh` | `destroy -f` puis `up` chronométré, puis contrôle général |
| V6 — Panne du répartiteur | `EXT=e1 essais/v6_panne_lb.sh` | `vagrant halt lb1` : service repris sur l'IP virtuelle .10 en moins de 5 s |
| R2 — Idempotence | `essais/r2_idempotence.sh` | Deux `vagrant provision` : aucun fichier de `/etc` modifié |

Chaque sortie commence par la commande, la date, le poste, `NB_APP`, `EXT`
et le commit : une mesure doit pouvoir être refaite à l'identique.
V2, V4 et V6 **arrêtent des machines** ; après V4, revenir à l'état initial
avec `v5_reconstruction.sh` (ne jamais relancer bdd1 seule).

**Supervision (E2)** : avec `EXT=e2` (ou `e1,e2`), Grafana est accessible
depuis l'hôte par le réseau privé sur <http://192.168.61.41:3000>, sans
compte (tableau de bord « RÉSULTATS-BF — Charge et pannes »).

`v5_reconstruction.sh` **détruit les machines** : le lancer avec les mêmes
`NB_APP` / `EXT` que lors de la création.

## Procédures d'exploitation

**Ajouter des serveurs applicatifs**

```bash
export NB_APP=4
vagrant up                 # crée app3 et app4, reprovisionne lb1
essais/controle_socle.sh   # « les 4 serveurs répondent »
```

La configuration HAProxy est réengendrée à chaque `vagrant up` du
répartiteur : aucune modification manuelle.

**Bascule de la base sur bdd2** (R6), depuis l'hôte, quand bdd1 est en panne :

```bash
bash scripts/bascule.sh             # refuse si bdd1 tourne encore
bash scripts/bascule.sh --forcer    # arrête d'abord PostgreSQL sur bdd1
```

1. Vérifie que bdd1 n'accepte plus d'écritures (jamais deux bases primaires).
2. Promeut bdd2 (`pg_promote`).
3. Réécrit `BDD_HOTE` dans `/etc/resultats-app/bdd_hote.env` sur chaque
   serveur applicatif : l'application le relit à chaque requête, sans
   redémarrage.
4. Attend que `/sante` réponde 200 à travers le répartiteur.

Chaque étape est horodatée ; `essais/v4_panne_bdd.sh` provoque la panne et
chronomètre la procédure. Après une bascule, revenir à l'état initial avec
`essais/v5_reconstruction.sh` : ne jamais relancer bdd1 seule, elle se
croirait encore primaire.

## Dépannage

| Symptôme | Cause | Solution |
| --- | --- | --- |
| `The box you're attempting to add doesn't support the provider` | Vagrant sous Windows ne détecte pas l'architecture de l'hôte | Corrigé dans le `Vagrantfile` (`box_architecture`) : faire `git pull` |
| `Fichier .env absent` | `.env` n'a pas été créé | `cp .env.exemple .env` puis le compléter |
| `vagrant introuvable` en lançant un essai depuis PowerShell | `bash` y désigne WSL | Utiliser `essais\lancer.cmd <essai>` |
| Une fenêtre s'ouvre puis se ferme | `.sh` lancé par double-clic ou `.\essais\x.sh` | Utiliser `essais\lancer.cmd <essai>` |
| VM très lentes ou `vagrant up` qui échoue au démarrage | Mémoire libre insuffisante | Libérer 3 Go (fermer Docker Desktop, navigateurs) |
| Machines allumées que `vagrant status` ne montre pas | `destroy` lancé sans les mêmes `NB_APP` / `EXT` | Relancer `vagrant destroy -f` avec les variables d'origine |

## Arborescence

| Chemin | Contenu |
| --- | --- |
| `Vagrantfile` | Définition des machines (table `NOEUDS`) |
| `scripts/` | Provisionnement : `commun.sh` + un script par rôle |
| `app/` | Service HTTP (`/resultat`, `/sante`, `/info`) |
| `config/` | Configurations ; `noeuds.yml` y est engendré ; `keepalived/` pour E1, `grafana/` (tableau de bord) pour E2 |
| `essais/` | Scripts d'essai, lanceur Windows `lancer.cmd` ; sorties dans `essais/resultats/` |
| `CONTRATS.md` | Conventions entre membres : ports, noms, schéma de la table |
| `JOURNAL.md` | Journal de bord : décisions, difficultés |

## Règles de contribution

- **Secrets** : jamais dans un fichier versionné. Ils vivent dans `.env`
  (ignoré par Git) ; `.env.exemple` en donne la liste.
- **Fins de ligne** : LF partout, imposé par `.gitattributes` (sauf les
  `.cmd`, en CRLF). Sous Windows, ne pas modifier ce réglage dans l'éditeur.
- **Idempotence** : dans les scripts, utiliser les fonctions de
  `scripts/commun.sh` (`installer_paquets`, `ecrire_si_different`,
  `ajouter_ligne`) plutôt que `apt-get` ou `>>` directement. Rejouer
  `vagrant provision` deux fois avant de pousser.
- **Branches** : une branche par personne et par tâche, jamais de commit
  direct sur `main`, jamais de dépôt de fichiers par le site GitHub.
  KUELA relit et fusionne.
- **Messages de commit** : dire ce qui change et pourquoi
  (« replique.sh : ne recopie plus bdd1 après une bascule »), pas
  « Modifier le code ».
- **Services réseau** : écouter sur `0.0.0.0`, jamais `127.0.0.1`.

## Équipe

| Membre | Rôle |
| --- | --- |
| SIMPORE Wend-Yam Lysias Eldad | Architecte réseau et répartition |
| OUEDRAOGO D. Adan Franck | Ingénieur applicatif |
| KAGAMBEGA Hermann | Ingénieur données |
| NIKIEMA Shun Arion | Ingénieur essais et observabilité |
| KUELA Abdoul Raof | Intégration, reproductibilité et documentation |
