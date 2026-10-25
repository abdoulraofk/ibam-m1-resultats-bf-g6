# Dossier d'architecture — RÉSULTATS-BF

**Groupe 6** — M1 Informatique, IBAM / Université Joseph KI-ZERBO
Virtualisation et Cloud Computing (Dr SOMDA) — année 2026-2027

| Membre | Rôle |
| --- | --- |
| SIMPORE Wend-Yam Lysias Eldad | Architecte réseau et répartition |
| OUEDRAOGO D. Adan Franck | Ingénieur applicatif |
| KAGAMBEGA Hermann | Ingénieur données |
| NIKIEMA Shun Arion | Ingénieur essais et observabilité |
| KUELA Abdoul Raof | Intégration, reproductibilité et documentation |

Dépôt : <https://github.com/abdoulraofk/ibam-m1-resultats-bf-g6>

> **À faire avant le rendu — supprimer cet encadré.**
> Les passages en *italique entre crochets* attendent une mesure ou une
> vérification. Le tableau du § 5 s'engendre avec
> `essais/tableau_resultats.sh` : ne recopier aucun chiffre à la main.

---

## 1. Le cas et les exigences

Chaque année, la publication des résultats d'examen fait tomber le site de
consultation dans les minutes qui suivent l'annonce. La cause est rarement
le programme : c'est l'infrastructure, pensée ni pour absorber un pic, ni
pour survivre à la panne d'une machine.

La plateforme RÉSULTATS-BF permet à un candidat de consulter son résultat à
partir de son numéro de matricule. Deux exigences non fonctionnelles priment
sur toutes les autres :

- **Résilience** — la panne d'une machine n'interrompt pas le service.
- **Scalabilité** — absorber davantage de trafic se fait en ajoutant des
  machines, sans réécrire la configuration.

Une troisième contrainte les conditionne : **toute l'infrastructure est
décrite en code** et se reconstruit sur n'importe quel poste sans un seul
geste manuel. Une infrastructure qui ne se reconstruit pas n'est pas une
infrastructure.

**Hors périmètre.** L'application est volontairement minimale : elle ne gère
ni authentification, ni publication des résultats, ni chiffrement du
transport. Ce qui est construit et évalué ici, c'est l'infrastructure autour
d'elle.

**Hypothèses de dimensionnement.** La base contient 50 000 résultats, volume
suffisant pour que les mesures de charge aient un sens. Le socle obligatoire
tient dans 3 Go de mémoire, sur un poste de 8 Go, toutes machines sur le
même hôte physique — ce dernier point pèse lourd sur l'interprétation des
mesures de débit (§ 5.3).

## 2. Architecture

![Architecture de la plateforme](schema_architecture.png)

*Figure 1 — Architecture de la plateforme RÉSULTATS-BF (groupe 6)*

### 2.1 Inventaire des machines

| Machine | Rôle | Adresse | RAM | Statut |
| --- | --- | --- | --- | --- |
| bdd1 | PostgreSQL 16 primaire, lecture et écriture | 192.168.61.31 | 768 Mo | Socle |
| bdd2 | Réplique en flux, promouvable | 192.168.61.32 | 768 Mo | Socle |
| app1 … appN | Serveurs applicatifs sans état (N ≥ 2) | 192.168.61.21 … | 512 Mo | Socle |
| lb1 | Répartiteur HAProxy actif | 192.168.61.11 | 512 Mo | Socle |
| lb2 | Répartiteur passif, IP virtuelle .10 | 192.168.61.12 | 512 Mo | Extension E1 |
| obs | Prometheus et Grafana | 192.168.61.41 | 768 Mo | Extension E2 |

Le socle représente cinq machines et 3 072 Mo de mémoire.

### 2.2 Plan d'adressage

Depuis la version 6.1.28, VirtualBox n'autorise les réseaux privés
hôte-seul que dans la plage 192.168.56.0/21. Modifier ce réglage exigerait
de toucher `/etc/vbox/networks.conf` sur chaque poste, ce qui rendrait le
dépôt non reproductible. Le groupe 6 travaille donc sur **192.168.61.0/24**
(X = 55 + 6).

Les derniers octets sont attribués par famille, pour que l'adresse dise le
rôle : `.11` et `.12` pour les répartiteurs, `.10` pour leur adresse
virtuelle partagée, `.21` à `.2N` pour les serveurs applicatifs, `.31` et
`.32` pour les bases, `.41` pour la supervision.

### 2.3 Chemin d'une requête

1. Le navigateur appelle `http://localhost:8080/resultat?matricule=M000042`.
   C'est **le seul port exposé vers l'hôte**, redirigé vers le port 80 de
   lb1 et limité à 127.0.0.1 (exigence R8).
2. HAProxy choisit un serveur applicatif en tourniquet, parmi ceux qui
   répondent à la sonde `GET /sante`.
3. Le serveur applicatif lit l'adresse de la base dans
   `/etc/resultats-app/bdd_hote.env`, ouvre une connexion, interroge la
   table `resultats`, referme la connexion et renvoie un JSON.
4. bdd1 réplique en flux vers bdd2, en continu.
5. En parallèle, Prometheus interroge toutes les cinq secondes
   `node_exporter` sur chaque machine (port 9100) et l'exportateur intégré
   de HAProxy (port 8404).

Tout le reste du trafic — base de données, métriques, réplication, Grafana —
**ne quitte jamais le réseau privé**.

### 2.4 La source unique de vérité

C'est la pièce centrale de l'architecture. La table `NOEUDS`, en tête du
`Vagrantfile`, décrit les machines :

```ruby
NOEUDS << { nom: "bdd1", ip: "#{RESEAU}.31", mem: 768, role: "bdd" }
(1..NB_APP).each do |i|
  NOEUDS << { nom: "app#{i}", ip: "#{RESEAU}.#{20 + i}", mem: 512, role: "app" }
end
```

À chaque commande Vagrant, cette table est écrite dans
`config/noeuds.yml`. Les scripts de provisionnement lisent ce fichier par
les fonctions `noeuds_par_role` et `ip_de` de `scripts/commun.sh`. La
configuration de HAProxy est donc **engendrée** à partir de la même table
que les machines :

```bash
SERVEURS="$(noeuds_par_role app)"
while read -r nom ip; do
    printf '    server %s %s:%s check\n' "$nom" "$ip" "$PORT_APP"
done <<< "$SERVEURS"
```

Conséquence directe : passer de deux à quatre serveurs ne demande que
`NB_APP=4 vagrant up`. Aucune adresse n'est écrite en dur, nulle part. Sans
cela, « scalable » ne serait qu'un mot — et le barème retire deux points.

## 3. Justification des choix

| Choix | Pourquoi | Écarté |
| --- | --- | --- |
| Source unique de vérité (`NOEUDS` → `noeuds.yml`) | Une seule table décrit les machines et alimente le répartiteur : R3 tient par construction | Liste de serveurs maintenue à la main dans `haproxy.cfg` |
| HAProxy | Sonde HTTP fine (`inter 1s fall 2 rise 2`), rejeu d'une requête restée sans réponse, exportateur Prometheus intégré | Nginx : sonde active moins fine en version libre |
| Application sans état | Ajouter ou retirer un serveur est sans effet sur les utilisateurs ; tout l'état vit en base | Sessions en mémoire, fichiers locaux |
| `BDD_HOTE` dans un fichier relu à chaque requête | La bascule de la base ne demande aucun redémarrage : elle réécrit un fichier | Variable d'environnement figée au démarrage du service |
| Réplication en flux PostgreSQL | Réplique utilisable en lecture, promouvable en une commande, retard de l'ordre de la seconde | Sauvegarde et restauration périodique |
| keepalived en **unicast** | La multidiffusion est peu fiable sur le réseau hôte-seul de VirtualBox | VRRP en multidiffusion |
| Sonde keepalived sur `/lb_sante` | Servie par HAProxy lui-même : elle ne consomme pas un tour du tourniquet (§ 5.1) | Sonde sur `/sante`, qui traverse le répartiteur |
| Erreurs HAProxy en JSON | Une panne renvoie le même format que l'application, jamais une page HTML inattendue | Page d'erreur par défaut |
| Fonctions idempotentes dans `commun.sh` | `ecrire_si_different` et `ajouter_ligne` rendent R2 vérifiable ; un service n'est rechargé que si sa configuration a changé | `>>` et réécriture systématique |
| gunicorn, deux processus | Suffisant pour 512 Mo par machine ; permet de servir plusieurs requêtes simultanées | Serveur de développement Flask, à processus unique |
| Six heures d'historique Prometheus | Largement assez pour une démonstration, et ménage les 768 Mo de la machine | Rétention par défaut de quinze jours |

**Un choix imposé par la réalité.** Le sujet épingle la boîte
`bento/ubuntu-24.04` en version `202404.23.0`. Cette version n'est pas
publiée sur Vagrant Cloud : nous avons dû épingler `202510.26.0`, et fixer
explicitement l'architecture `amd64`, faute de quoi Vagrant sous Windows
tente de télécharger l'image ARM (§ 6).

## 4. Procédures d'exploitation

### 4.1 Construire ou reconstruire la plateforme

```bash
git clone https://github.com/abdoulraofk/ibam-m1-resultats-bf-g6.git
cd ibam-m1-resultats-bf-g6
cp .env.exemple .env        # puis remplacer chaque « a_changer »
vagrant up
essais/controle_socle.sh    # verdict OK / KO point par point
```

Sous PowerShell, les essais se lancent par `essais\lancer.cmd <essai>` :
dans PowerShell, `bash` désigne WSL, où Vagrant ne voit pas les machines
VirtualBox.

### 4.2 Ajouter des serveurs applicatifs

```bash
export NB_APP=4
vagrant up                 # crée app3 et app4, reprovisionne les répartiteurs
essais/controle_socle.sh
```

Les répartiteurs sont reprovisionnés à chaque `vagrant up` (`run: "always"`)
et leur configuration est réengendrée : **aucune modification manuelle**.

Détruire avec la même valeur de `NB_APP`, sinon app3 et app4 restent
allumées dans VirtualBox sans être gérées par Vagrant.

### 4.3 Basculer la base sur bdd2

```bash
bash scripts/bascule.sh             # refuse si bdd1 accepte encore des écritures
bash scripts/bascule.sh --forcer    # arrête d'abord PostgreSQL sur bdd1
```

1. **Vérifier que bdd1 n'accepte plus d'écritures.** Sans ce garde-fou, deux
   bases primaires divergeraient et aucune réconciliation ne serait possible.
2. **Promouvoir bdd2** (`pg_promote`). L'étape est sautée si bdd2 est déjà
   primaire, ce qui rend la procédure rejouable.
3. **Faire pointer les serveurs applicatifs sur bdd2** en réécrivant
   `/etc/resultats-app/bdd_hote.env`. L'application relit ce fichier à
   chaque requête : **aucun redémarrage**.
4. **Vérifier** que `/sante` répond 200 à travers le répartiteur.

Chaque étape est horodatée. En ligne de commande dans la machine, la
promotion se fait avec le chemin complet, `pg_ctl` n'étant pas dans le
PATH :

```bash
sudo -u postgres /usr/lib/postgresql/16/bin/pg_ctl promote -D /var/lib/postgresql/16/main
```

**Après une bascule, ne jamais relancer bdd1 seule** : elle se croirait
encore primaire. Le retour à l'état initial passe par
`essais/v5_reconstruction.sh`.

### 4.4 Superviser

Avec `EXT=e2`, Grafana est accessible depuis l'hôte, par le réseau privé,
sur <http://192.168.61.41:3000> (tableau de bord « RÉSULTATS-BF — Charge et
pannes », consultation sans compte). On y lit le débit total et par serveur,
le nombre de serveurs en service, les machines joignables, le processeur et
les erreurs 5xx.

## 5. Résultats des scénarios de validation

Toutes les valeurs viennent de `essais/resultats/`. Chaque fichier commence
par la commande, la date, le poste, `NB_APP`, `EXT` et le commit : la mesure
est reproductible. Le tableau ci-dessous s'engendre par
`essais/tableau_resultats.sh`.

*[Coller ici la sortie de `essais/tableau_resultats.sh`.]*

### 5.1 V1 — Répartition, et la mesure qui ne mesurait pas ce qu'on croyait

Attendu : les N serveurs apparaissent tour à tour ; écart entre le plus et
le moins sollicité inférieur à 20 %.

Les deux premiers essais à quatre serveurs ont donné **40 % d'écart**
(6/5/5/4, puis 6/4/4/6). Le réflexe aurait été d'incriminer l'algorithme de
répartition. La cause était ailleurs : la sonde de keepalived interrogeait
`/sante` **à travers** le répartiteur, et consommait donc un tour du
tourniquet **chaque seconde**. Les 20 appels de l'essai se répartissaient
entre les quatre serveurs *et* la sonde.

En basculant la sonde sur `/lb_sante`, servie par HAProxy lui-même
(`monitor-uri`), la répartition est devenue exacte : **5/5/5/5, soit 0 %
d'écart**. Les quatre fichiers de mesure sont conservés dans
`essais/resultats/`, y compris les deux qui échouent : ils font partie du
résultat.

### 5.2 V2 — Panne d'un serveur applicatif

Attendu : le service reste disponible, plus aucune erreur au-delà de cinq
secondes après la panne.

*[Lancer `essais/v2_panne_app.sh` et commenter : nombre de requêtes perdues,
durée de la période dégradée. Préciser que HAProxy écarte un serveur après
deux échecs de sonde espacés d'une seconde, et qu'une requête partie vers le
serveur qui tombe est rejouée sur un autre (`retry-on`).]*

### 5.3 V3 — Montée en charge

Attendu : le débit augmente lorsqu'on ajoute des serveurs.

*[Lancer `essais/v3_charge.sh` avec NB_APP=2 puis NB_APP=4 et reporter les
deux débits médians.]*

**Interprétation, à écrire honnêtement.** Les machines virtuelles se
partagent le processeur d'un seul ordinateur. Doubler le nombre de serveurs
applicatifs ne double donc pas le débit, et il peut baisser : chaque machine
supplémentaire prend du temps processeur aux autres. Ce n'est pas un échec,
c'est un résultat, et il s'explique. Deux autres facteurs pèsent : chaque
requête ouvre et referme une connexion à la base, et gunicorn tourne avec
deux processus par machine.

### 5.4 V4 — Panne de la base primaire

Attendu : le service renvoie proprement 503 — jamais une page blanche ni une
erreur de connexion brute — puis la bascule rétablit le service.

*[Lancer `essais/v4_panne_bdd.sh` et reporter la durée de la procédure.]*

Deux points à expliquer :

- **Ce qui est renvoyé pendant la panne.** L'application répond
  `{"etat":"ko"}` en 503 ; le détail de l'erreur PostgreSQL part dans le
  journal du service, jamais dans la réponse. Quand tous les serveurs sont
  écartés, HAProxy renvoie lui aussi un 503 en JSON.
- **Ce que mesure le chiffre.** Nous distinguons la *durée de la procédure
  de bascule* — du lancement du script au service rétabli — de
  l'*indisponibilité totale vue du client*, qui comprend en plus l'arrêt de
  la machine et le temps de détection par un opérateur humain.

Un essai antérieur a affiché « 0 seconde » : la bascule avait déjà été faite
lors d'un essai précédent, et le test ne basculait plus rien. Le scénario
vérifie désormais que bdd2 est encore une réplique avant de commencer.

### 5.5 V5 — Reconstruction intégrale

Attendu : `vagrant destroy -f` puis `vagrant up` donnent une plateforme
fonctionnelle, sans aucune intervention.

**Mesuré : 17 min 38 s**, avec l'extension E1 (six machines), suivies du
contrôle complet qui conclut « plateforme conforme ». Aucune commande n'a
été tapée entre les deux. Cette durée comprend l'installation des paquets
dans chaque machine ; *[préciser si la boîte Vagrant était déjà en cache]*.

### 5.6 V6 — Panne du répartiteur (extension E1)

Attendu : le service reste joignable à la même adresse.

**Mesuré : 1,2 seconde** d'interruption maximale, **zéro requête en erreur
sur 688**, pendant que lb1 est arrêtée sous charge. Le journal de keepalived
sur lb2 montre `Entering MASTER STATE` au même moment : c'est bien la
bascule VRRP qui a repris l'adresse virtuelle.

Un détail de méthode mérite d'être signalé : la première version de l'essai
mesurait « arrêt de la machine → dernière erreur ». Cette mesure était
fausse, car `vagrant halt` met jusqu'à trente secondes à éteindre la
machine, qui sert normalement pendant ce temps. L'essai mesure désormais le
plus long intervalle sans aucune réponse.

### 5.7 R2 — Idempotence

*[Lancer `essais/r2_idempotence.sh` : il rejoue `vagrant provision` deux
fois et compare l'empreinte de chaque fichier de `/etc` sur chaque machine.]*

## 6. Limites connues et ce que nous ferions autrement

| Limite | Effet | Ce que nous ferions |
| --- | --- | --- |
| Bascule de la base déclenchée à la main | Quelques dizaines de secondes d'indisponibilité, dépendant de la réactivité d'un opérateur | Déclenchement automatique avec un témoin extérieur, pour éviter la double promotion |
| bdd1 ne revient pas en réplique après bascule | Une reconstruction complète est nécessaire | Script de retour en réplique avec `pg_rewind` |
| Une connexion à la base par requête | Limite le débit mesuré en V3 | Réserve de connexions (pgbouncer, ou pool applicatif) |
| Pas de chiffrement entre machines | Acceptable sur un réseau privé de laboratoire | TLS entre répartiteur et serveurs applicatifs |
| Grafana en consultation libre | Acceptable pour une démonstration | Authentification et comptes nominatifs |
| Toutes les machines sur un seul hôte | Les mesures de débit ne reflètent pas une production réelle | Répartir sur plusieurs machines physiques |
| Le temps de reconstruction dépend fortement de l'hôte | De 17 minutes à plusieurs heures selon le poste (§ 6.1) | Déclarer les prérequis d'hôte, pas seulement les versions d'outils |
| Deux extensions sur quatre | E3 (cache) et E4 (déploiement sans coupure) non traitées | Priorité donnée au socle, qui porte l'essentiel des exigences ; E4 est la plus accessible, la configuration du répartiteur s'y prête déjà |

### 6.1 Ce que « reconstructible sur n'importe quel poste » veut vraiment dire

Le sujet demande une infrastructure qui se reconstruit « sur n'importe quel
poste ». Nous l'avons vérifié sur trois machines, et le résultat nous a
surpris : **le code est bien reproductible, le temps de reconstruction ne
l'est pas du tout.**

| Poste | Résultat de `vagrant destroy -f && vagrant up` |
| --- | --- |
| Poste A | **17 min 38 s**, plateforme conforme, sans intervention |
| Poste B | Échec après 6 h 18, puis échec après 1 h 07 |

Sur le poste B, trois facteurs se cumulent :

- **VirtualBox s'exécute au-dessus de Hyper-V.** WSL 2 et Docker Desktop
  activent la plateforme de virtualisation de Windows ; VirtualBox n'a plus
  l'accès direct au processeur et bascule dans un mode de compatibilité
  nettement plus lent.
- **La mémoire disponible est insuffisante.** Le socle demande 3 Go ; il en
  restait 1,1 Go, les conteneurs Docker occupant le reste. Les machines
  passent alors leur temps à échanger avec le disque.
- **Le réseau est un partage de connexion mobile**, d'où des échecs de
  résolution de noms et de téléchargement pendant l'installation des
  paquets — c'est d'ailleurs ce qui a mis fin aux deux essais.

**Ce que nous en retenons.** Un dépôt reproductible ne garantit pas une
expérience reproductible. Nos scripts se sont comportés de la même manière
sur les deux postes : mêmes étapes, mêmes messages, et les reprises
automatiques d'`apt-get update` ont fonctionné comme prévu. Ce qui change,
c'est l'hôte. Un projet livré en entreprise devrait donc déclarer ses
prérequis d'hôte — mémoire libre réellement disponible, absence
d'hyperviseur concurrent, lien réseau stable — au même titre que les
versions de Vagrant et de VirtualBox. Nous avons ajouté ces trois points au
tableau de dépannage du `README.md`.

**Difficultés rencontrées.** Elles sont détaillées dans le journal de bord
(`docs/JOURNAL_DE_BORD.md`, § 3) : version de boîte inexistante,
architecture non détectée sous Windows, `apt-get update` qui réussit en
apparence, sonde qui fausse la répartition, reprovisionnement qui écrase une
base promue, VPN qui coupe le réseau privé.

## 7. Annexes

- **Installation et dépannage** : `README.md`.
- **Conventions entre composants** (ports, noms, schéma de la table) :
  `CONTRATS.md`.
- **Journal de bord** (livrable L3) : `docs/JOURNAL_DE_BORD.md`.
- **Déroulé de la démonstration** : `docs/DEMONSTRATION.md`.
- **Sorties brutes des essais** : `essais/resultats/`.
- **Schéma d'architecture**, engendré par `docs/schema_architecture.py`.
