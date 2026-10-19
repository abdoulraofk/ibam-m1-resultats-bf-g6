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
