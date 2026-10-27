# Journal de bord — Livrable L3

**Projet RÉSULTATS-BF — Groupe 6**
M1 Informatique, IBAM / Université Joseph KI-ZERBO — Virtualisation et Cloud
Computing (Dr SOMDA), 2026-2027

Période : du lundi 19 au dimanche 25 octobre 2026.
Le détail jour par jour est dans `JOURNAL.md`, à la racine du dépôt.

---

## 1. Répartition des rôles

Le sujet prévoit quatre rôles ; nous sommes cinq. Nous avons ajouté un
cinquième rôle, **intégration, reproductibilité et documentation**, qui
couvre la reconstruction intégrale (R1), l'idempotence (R2), l'absence de
secrets (R7) et le README.

| Membre | Rôle | Périmètre |
| --- | --- | --- |
| SIMPORE Wend-Yam Lysias Eldad | Architecte réseau et répartition | Vagrantfile, HAProxy, sonde de santé, extension E1 |
| OUEDRAOGO D. Adan Franck | Ingénieur applicatif | Service HTTP sans état, gestion des erreurs de base |
| KAGAMBEGA Hermann | Ingénieur données | PostgreSQL, jeu de données, réplication, bascule |
| NIKIEMA Shun Arion | Ingénieur essais et observabilité | Scénarios V1 à V6, campagne de mesures, extension E2 |
| KUELA Abdoul Raof | Intégration et documentation | Dépôt, fonctions communes, relectures, fusions, dossier |

Chaque membre relit et fusionne par l'intermédiaire de KUELA : une branche
par personne, aucun commit direct sur `main`, et `main` ne reçoit que du
code dont le provisionnement a été vérifié.

## 2. Décisions d'architecture et pourquoi

| Décision | Raison |
| --- | --- |
| Table `NOEUDS` du Vagrantfile comme source unique de vérité | La configuration du répartiteur est engendrée depuis la même table que les machines : `NB_APP=4` suffit (R3), sans adresse écrite à la main. |
| Fonctions idempotentes communes (`scripts/commun.sh`) | `ecrire_si_different` et `ajouter_ligne` remplacent `>>` et les réécritures : c'est ce qui rend R2 vérifiable. |
| `BDD_HOTE` dans un fichier relu à chaque requête | La bascule de la base ne demande aucun redémarrage de l'application. |
| keepalived en unicast | La multidiffusion est peu fiable sur le réseau hôte-seul de VirtualBox. |
| Sonde keepalived sur `/lb_sante` et non `/sante` | Sur `/sante`, la sonde traversait le répartiteur et prenait un tour de la répartition chaque seconde (voir § 4). |
| Un fichier de résultat horodaté par essai | Chaque sortie porte la commande, la date, le poste, `NB_APP` et le commit : la mesure est reproductible. |

## 3. Difficultés rencontrées et comment elles ont été levées

**La version de boîte du sujet n'existe pas.** L'annexe A impose
`bento/ubuntu-24.04` en version `202404.23.0`. Vagrant Cloud ne publie pas
cette version : `vagrant up` échouait pour tout le monde. Nous avons épinglé
`202510.26.0`.

**Vagrant ne détectait pas l'architecture du poste.** Pour cette version,
l'image VirtualBox « par défaut » est celle des processeurs ARM. Sous
Windows, `vagrant up` répondait « the box doesn't support the provider ».
Résolu en fixant explicitement l'architecture dans le Vagrantfile (`amd64`,
ou `arm64` sur un Mac Apple Silicon).

**`apt-get update` réussit même quand un dépôt est injoignable.** Notre
fonction posait alors un témoin et l'index restait périmé six heures.
Signalé par SIMPORE, corrigé avec `--error-on=any` et trois tentatives : le
témoin n'est posé qu'en cas de succès réel.

**La répartition semblait déséquilibrée (40 % d'écart).** Le scénario V1
donnait 6/5/5/4 sur quatre serveurs. La cause n'était pas HAProxy : la sonde
de keepalived interrogeait `/sante` **à travers** le répartiteur et
consommait un tour de la répartition chaque seconde. En la basculant sur
`/lb_sante`, servi par HAProxy lui-même, la répartition est devenue
parfaite : 5/5/5/5. Le premier chiffre mesuré n'était pas faux : il
mesurait la sonde en plus des serveurs applicatifs.

**Reprovisionner après une bascule effaçait la base promue.** Le script de
la réplique décidait de recopier bdd1 quand `standby.signal` était absent.
Or la promotion supprime justement ce fichier : un `vagrant provision bdd2`
après bascule écrasait toutes les écritures faites sur bdd2. Résolu par un
marqueur posé après la première copie réussie, qui survit aux
provisionnements mais pas à `vagrant destroy`.

**Une mesure de bascule à « zéro seconde ».** Un essai a affiché une durée
nulle : la bascule avait déjà été faite lors d'un essai précédent, et le
test ne basculait donc plus rien. Le scénario V4 vérifie désormais que bdd2
est encore une réplique avant de provoquer la panne, et s'arrête sinon.

**Un VPN coupe l'accès au réseau privé.** Depuis l'hôte, plus rien ne
répondait sur 192.168.61.x, machines pourtant démarrées. Les messages
d'erreur des essais nomment maintenant cette cause.

**Le temps de reconstruction dépend de l'hôte, pas du dépôt.** La même
commande a pris 17 min 38 s sur un poste et a échoué après plus de six
heures sur un autre. Nos scripts se sont pourtant comportés à l'identique.
La différence tient à l'hôte : VirtualBox s'exécutant au-dessus de Hyper-V
(activé par WSL 2 et Docker Desktop), à la mémoire réellement libre, et à un
partage de connexion mobile qui faisait échouer les téléchargements. Les
prérequis d'hôte sont désormais listés dans le README, et la question est
discutée au § 6.1 du dossier.

**Sous Windows, `bash` désigne WSL.** Lancés depuis PowerShell, les scripts
d'essai ne voyaient pas les machines VirtualBox. Nous avons ajouté un
lanceur `essais\lancer.cmd` qui appelle explicitement Git Bash.

## 4. Bilan

- **Comprendre chaque chiffre avant de le publier.** Deux mesures
  initialement erronées (40 % d'écart en V1, 0 seconde de bascule en V4)
  ont permis d'identifier puis de corriger deux défauts réels de
  l'infrastructure.
- **Un provisionnement non idempotent ne se voit qu'au second passage.**
  Rejouer systématiquement `vagrant provision` a révélé plusieurs défauts
  qu'un seul passage aurait laissés invisibles.
- **La reproductibilité se vérifie sur un autre poste.** Les erreurs de
  version de boîte et de lancement sous PowerShell n'apparaissaient pas sur
  le poste qui avait écrit le code, seulement sur celui qui l'exécutait pour
  la première fois.
- **Un commit régulier conditionne l'avancement du projet.** Les tâches
  restées sur un poste sans être poussées n'ont pas pu être relues ni
  intégrées dans les délais prévus.
