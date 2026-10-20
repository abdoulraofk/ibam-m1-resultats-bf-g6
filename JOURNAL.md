# Journal de bord — Groupe 6

Une ligne par décision ou difficulté : date, auteur, quoi, pourquoi.
Ce fichier sert à rédiger le livrable L3.

| Date | Auteur | Décision ou difficulté | Pourquoi / comment résolu |
| --- | --- | --- | --- |
| 2026-10-19 | KUELA | Rendu fixé au 25 octobre : le planning de 4 semaines du sujet est compressé en 7 jours, un jalon par soir, gel du code vendredi 23 à 20 h. | Date limite communiquée au groupe. |
| 2026-10-19 | KUELA | 5 membres pour 4 rôles : ajout d'un rôle « intégration, reproductibilité et documentation ». | Couvrir R1, R2, R7 et le README, les points les plus pénalisés du barème. |
| 2026-10-19 | KUELA | Extensions retenues : E1 (lb2 + VRRP) et E2 (Prometheus + Grafana) seulement. | Les extensions valent 2 points sur 20 ; le socle passe d'abord. |
| 2026-10-19 | KUELA | `.gitattributes` impose LF sur tous les fichiers texte, dès le premier commit. | Un script en CRLF échoue dans la VM (piège n° 5 du sujet). |
| 2026-10-19 | KUELA | Secrets dans `.env` (ignoré par Git), lus par `charger_env` dans `scripts/commun.sh` ; le provisionnement s'arrête avec un message clair si `.env` manque. | Exigence R7 ; une erreur explicite vaut mieux qu'une base sans mot de passe. |
| 2026-10-19 | KUELA | `config/noeuds.yml` n'est pas versionné. | Il est engendré par le Vagrantfile à chaque exécution ; le versionner créerait une seconde source de vérité. |
| 2026-10-20 | KUELA | Branche `simpore` (Vagrantfile) relue, non fusionnée : la version de boîte `202404.23.0` de l'annexe A n'existe pas sur Vagrant Cloud, et les scripts de rôle appelés sont absents. | Les deux font échouer `vagrant up`. Correction demandée : version `202510.26.0` et un script provisoire par rôle. |
| 2026-10-20 | KUELA | Jalon de lundi soir non atteint : seuls SIMPORE et KUELA ont poussé un commit. | À traiter au point du matin avec OUEDRAOGO, KAGAMBEGA et NIKIEMA. |
| 2026-10-20 | KUELA | Test R2 automatisé (`essais/r2_idempotence.sh`) : empreintes SHA-256 de `/etc` sur chaque machine après deux `vagrant provision`, comparées fichier par fichier. | « Rejeu et comparaison des fichiers de configuration » est exactement la vérification du sujet ; un script la rend rejouable par l'enseignant. |
| 2026-10-20 | KUELA | Conventions entre membres écrites dans `CONTRATS.md`. | Permettre à chacun d'avancer sans attendre la brique d'un autre. |
| 2026-10-20 | KUELA | Branches `simpore` (Vagrantfile corrigé, `lb.sh`) et `Kagambega_bdd` (`bdd.sh`, `replique.sh`) fusionnées dans `main`. | Testées en conteneurs Ubuntu 24.04 faute de Vagrant sur le poste de revue : R2, R4, R5 et V1 vérifiées. Reste à confirmer par un vrai `vagrant up`. |
| 2026-10-20 | KUELA | `Kagambega_bdd` fusionnée en un seul commit, au nom de KAGAMBEGA ; archive zip retirée de `main`. | Le premier commit de la branche contenait des PDF nommés `.sh`, et un zip avait été poussé directement sur `main`. Règle rappelée : pas de téléversement par le site GitHub, pas de commit direct sur `main`. |
| 2026-10-20 | KUELA | Défaut trouvé dans `replique.sh` : rejouer `vagrant provision bdd2` après une bascule efface la base promue et la recopie depuis bdd1. Reproduit en test : la ligne écrite après la bascule a disparu. | Le test « est-ce déjà une réplique ? » (`standby.signal`) est faux après une promotion. À corriger par KAGAMBEGA avant le scénario V4 (jeudi) : poser un marqueur après la première copie et ne plus jamais recopier ensuite. |
| 2026-10-20 | KUELA | Tests en conteneurs faits sur 10.61.0.0/24 au lieu de 192.168.61.0/24, sous-réseau déjà occupé sur le poste de test. | Les scripts lisent toutes les adresses dans `noeuds.yml` : changer de sous-réseau n'a demandé que ce fichier, preuve qu'aucune adresse n'est écrite en dur. |
