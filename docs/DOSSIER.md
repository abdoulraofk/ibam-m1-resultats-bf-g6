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

> **État du document — à supprimer avant le rendu.**
> Squelette écrit par KUELA le 24/10. Chaque section porte le nom de son
> rédacteur et ce qui reste à y mettre. Les mesures déjà faites sont
> recopiées depuis `essais/resultats/` ; **les cases « à mesurer » doivent
> être remplies à partir des fichiers de ce dossier, jamais de mémoire**
> (une mesure inventée coûte 4 points).
> Cible : 10 à 15 pages. Rédaction samedi, chacun sa section.

---

## 1. Contexte et exigences

*Rédacteur : KUELA — ½ page*

La publication des résultats d'examen provoque un pic de consultations qui
fait tomber le site. La plateforme RÉSULTATS-BF permet à un candidat de
consulter son résultat à partir de son matricule, avec deux exigences non
fonctionnelles prioritaires :

- **Résilience** — la panne d'une machine n'interrompt pas le service.
- **Scalabilité** — absorber plus de trafic se fait en ajoutant des
  machines, sans réécrire la configuration.

Toute l'infrastructure est décrite en code (Vagrant + VirtualBox) et se
reconstruit sur n'importe quel poste sans aucun geste manuel.

*À compléter : volumétrie visée, hypothèses de charge, ce qui est hors
périmètre (authentification, publication des résultats…).*

## 2. Architecture

*Rédacteur : SIMPORE — 2 à 3 pages, schéma compris*

![Architecture de la plateforme](schema_architecture.png)

*Figure 1 — Architecture de la plateforme RÉSULTATS-BF (groupe 6)*

| Machine | Rôle | Adresse | RAM | Statut |
| --- | --- | --- | --- | --- |
| bdd1 | PostgreSQL 16 primaire | 192.168.61.31 | 768 Mo | Socle |
| bdd2 | Réplique en flux, promouvable | 192.168.61.32 | 768 Mo | Socle |
| app1 … appN | Serveurs applicatifs sans état (N ≥ 2) | 192.168.61.21 … | 512 Mo | Socle |
| lb1 | Répartiteur HAProxy actif | 192.168.61.11 | 512 Mo | Socle |
| lb2 | Répartiteur passif, IP virtuelle .10 | 192.168.61.12 | 512 Mo | Extension E1 |
| obs | Prometheus + Grafana | 192.168.61.41 | 768 Mo | Extension E2 |

*À compléter : chemin d'une requête de bout en bout, plan d'adressage et
pourquoi la plage 192.168.56.0/21 est imposée, ce que contient
`config/noeuds.yml`.*

## 3. Justification des choix

*Rédacteurs : chacun pour son domaine — 2 pages*

| Choix | Pourquoi | Ce qui a été écarté |
| --- | --- | --- |
| Source unique de vérité (table `NOEUDS` → `config/noeuds.yml`) | La configuration du répartiteur est engendrée depuis la même table que les VM : `NB_APP=4` suffit (R3) | Liste de serveurs écrite à la main dans `haproxy.cfg` (−2 points au barème) |
| HAProxy | Sonde HTTP `/sante`, retrait en moins de 5 s, rejeu d'une requête sans réponse, métriques intégrées | Nginx (sonde active moins fine en version libre) |
| Application sans état | Ajouter ou retirer un serveur est sans effet ; tout l'état est en base | Sessions en mémoire |
| `BDD_HOTE` relu à chaque requête | La bascule ne demande aucun redémarrage de l'application | Variable d'environnement figée au démarrage |
| Réplication en flux PostgreSQL | Réplique utilisable en lecture et promouvable en une commande | Sauvegarde et restauration |
| keepalived en unicast (E1) | La multidiffusion est peu fiable sur le réseau hôte-seul de VirtualBox | VRRP en multidiffusion |
| Fonctions idempotentes dans `commun.sh` | `ecrire_si_different` et `ajouter_ligne` évitent les doublons au rejeu (R2) | `>>` direct (piège n° 2 du sujet) |

*À compléter : une phrase de justification par ligne, et les choix propres
à chaque domaine (version de PostgreSQL, gunicorn, 6 h d'historique
Prometheus…).*

## 4. Procédures d'exploitation

*Rédacteurs : KAGAMBEGA (bascule), SIMPORE (ajout de serveur) — 1 à 2 pages*

### 4.1 Ajouter des serveurs applicatifs

```bash
export NB_APP=4
vagrant up                 # crée app3 et app4, reprovisionne les répartiteurs
essais/controle_socle.sh   # « les 4 serveurs répondent »
```

La configuration HAProxy est réengendrée : aucune modification manuelle.
Détruire avec la même variable, sinon app3 et app4 restent allumées.

### 4.2 Bascule de la base sur bdd2

```bash
bash scripts/bascule.sh             # refuse si bdd1 accepte encore des écritures
bash scripts/bascule.sh --forcer    # arrête d'abord PostgreSQL sur bdd1
```

1. Vérifie que bdd1 n'accepte plus d'écritures (jamais deux primaires).
2. Promeut bdd2 (`pg_promote`).
3. Réécrit `BDD_HOTE` sur chaque serveur applicatif, sans redémarrage.
4. Attend `/sante` = 200 à travers le répartiteur.

*À compléter : retour à la normale après bascule, et ce qu'il advient de
bdd1 (reconstruite en réplique de bdd2, ou limite assumée).*

## 5. Résultats des scénarios de validation

*Rédacteur : NIKIEMA — 2 à 3 pages*

Toutes les valeurs ci-dessous viennent de `essais/resultats/`. Chaque
fichier commence par la commande, la date, le poste, `NB_APP`, `EXT` et le
commit : la mesure est reproductible.

| N° | Scénario | Mesure attendue | Résultat | Fichier |
| --- | --- | --- | --- | --- |
| V1 | Répartition, 20 appels à `/info`, N=4 | Écart (max − min) / moyenne < 20 % | **0 %** (5/5/5/5) | `v1_repartition_20261023_150214.txt` |
| V2 | Panne d'app1 sous charge | Requêtes perdues, période dégradée | *à mesurer sur VM* | *(à produire)* |
| V3 | `ab -n 2000 -c 50`, N=2 puis N=4 | Requêtes par seconde | *à mesurer sur VM* | *(à produire)* |
| V4 | Panne de bdd1 puis bascule | Durée de la procédure | *à mesurer sur VM* | *(à produire)* |
| V5 | `destroy -f` puis `up` | Durée de la reconstruction | **17 min 38 s**, plateforme conforme | `v5_reconstruction_20261022_162437.txt` |
| V6 | Panne de lb1 (E1) | Temps de reprise | **1,2 s** d'interruption, 0 erreur sur 688 requêtes | `v6_panne_lb_20261022_164444.txt` |
| R2 | `vagrant provision` deux fois | Aucun fichier de `/etc` modifié | *à mesurer sur VM* | *(à produire)* |

**Commentaire des mesures** *(à rédiger)* :

- **V1** — deux essais antérieurs donnaient 40 % d'écart : la sonde de
  keepalived interrogeait `/sante` à travers le répartiteur et prenait un
  tour du roundrobin chaque seconde. Corrigée (`monitor-uri /lb_sante`),
  la répartition est parfaite. *Garder ce récit : il montre une mesure
  comprise, pas seulement obtenue.*
- **V3** — *honnêteté exigée par le sujet : les VM partagent un seul
  processeur. Si le débit ne double pas, ou baisse, l'expliquer plutôt que
  de maquiller la courbe.*
- **V4** — distinguer la durée de la procédure de bascule et
  l'indisponibilité totale vue du client.
- **V5** — 17 min 38 s dont le téléchargement de la boîte et
  l'installation des paquets ; indiquer si la boîte était déjà en cache.
- **E2** — insérer une capture du tableau de bord Grafana pendant V2 ou
  V3 : on y voit le débit monter et un serveur disparaître.

## 6. Limites connues et ce que nous ferions autrement

*Rédacteur : KUELA, avec l'avis de chacun — 1 page*

| Limite | Effet | Piste |
| --- | --- | --- |
| Bascule de la base déclenchée à la main | Quelques dizaines de secondes d'indisponibilité | Déclenchement automatique, avec garde-fou contre la double promotion |
| bdd1 ne revient pas en réplique après bascule | Reconstruction complète nécessaire | Script de retour en réplique (`pg_rewind`) |
| Une connexion à la base par requête | Limite le débit mesuré en V3 | Réserve de connexions (pgbouncer ou pool applicatif) |
| Pas de chiffrement entre les machines | Acceptable sur réseau privé de laboratoire | TLS entre répartiteur et applications |
| Grafana en consultation libre | Acceptable pour la démonstration | Authentification et comptes nominatifs |
| Toutes les VM sur un seul poste | Les mesures de débit ne reflètent pas une vraie production | Répartir sur plusieurs machines physiques |

*À compléter : une ligne par difficulté réellement rencontrée (voir
`JOURNAL.md`), par exemple l'architecture de la boîte Vagrant sous Windows
ou `apt-get update` qui réussit en apparence.*

## 7. Annexes

- Arborescence du dépôt et rôle de chaque fichier (voir `README.md`).
- Conventions entre composants (voir `CONTRATS.md`).
- Journal de bord, livrable L3 (voir `JOURNAL.md`).
- Sorties brutes des essais : `essais/resultats/`.
