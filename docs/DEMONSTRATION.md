# Démonstration — déroulé et répétition (livrable L4)

20 minutes, sur une machine vierge : destruction, reconstruction en direct,
puis **trois scénarios tirés au sort par l'enseignant**.

L'enseignant choisit qui répond : **chacun doit savoir lancer et expliquer
une partie qu'il n'a pas écrite.**

---

## 1. Avant la démonstration (la veille)

- [ ] Cloner le dépôt **hors d'un dossier synchronisé** (pas OneDrive, pas
      Dropbox) : par exemple `C:\dev\ibam-m1-resultats-bf-g6`.
- [ ] `cp .env.exemple .env` puis remplacer chaque `a_changer`.
- [ ] **Télécharger la boîte à l'avance** : `vagrant box add bento/ubuntu-24.04
      --box-version 202510.26.0 --provider virtualbox --architecture amd64`
      (environ 1 Go ; sans cela, la reconstruction dure 15 minutes de plus).
- [ ] **Couper le VPN** s'il y en a un : il bloque l'accès au réseau privé.
- [ ] **Fermer Docker Desktop**, les navigateurs et les éditeurs lourds :
      il faut 3 Go de mémoire libre.
- [ ] Vérifier l'espace disque : environ 12 Go pour six machines.
- [ ] Faire une répétition complète chronométrée.
- [ ] **Aucun commit après la répétition.**

## 2. Déroulé proposé (20 minutes)

| Temps | Quoi | Qui | Commande |
| --- | --- | --- | --- |
| 0–2 min | Présenter le cas et les deux exigences : résilience, scalabilité. Montrer le schéma d'architecture. | SIMPORE | `docs/schema_architecture.png` |
| 2–4 min | Lancer la reconstruction **tout de suite** : elle tourne pendant les explications. | KUELA | `essais\lancer.cmd v5_reconstruction` |
| 4–9 min | Pendant la reconstruction : expliquer la source unique de vérité (table `NOEUDS` → `noeuds.yml` → configuration HAProxy engendrée), l'application sans état, la réplication. | OUEDRAOGO, KAGAMBEGA | Montrer `Vagrantfile`, `scripts/lb.sh`, `CONTRATS.md` |
| 9–11 min | La reconstruction se termine : lire le verdict du contrôle et la durée. | KUELA | sortie dans `essais/resultats/` |
| 11–18 min | **Trois scénarios tirés au sort.** | celui que l'enseignant désigne | voir § 3 |
| 18–20 min | Limites connues et ce que nous ferions autrement. | NIKIEMA | `docs/DOSSIER.md`, § 6 |

Si la reconstruction est trop longue pour le temps imparti, la lancer avant
l'entrée de l'enseignant et la **relancer** devant lui : il doit voir
qu'aucune commande n'est tapée à la main.

## 3. Les six scénarios : commande, durée, ce qu'on montre

| N° | Commande | Durée | Ce qu'on montre, en une phrase |
| --- | --- | --- | --- |
| V1 | `essais\lancer.cmd v1_repartition` | ~15 s | Les N serveurs répondent tour à tour ; écart inférieur à 20 %. |
| V2 | `essais\lancer.cmd v2_panne_app` | ~1 min | Un serveur applicatif est arrêté sous charge : le service continue, aucune erreur au-delà de 5 s. |
| V3 | `essais\lancer.cmd v3_charge` | ~3 min | Débit mesuré à 2 puis 4 serveurs ; **commenter honnêtement** : toutes les machines partagent un seul processeur. |
| V4 | `essais\lancer.cmd v4_panne_bdd` | ~2 min | La base primaire tombe : 503 propre, jamais d'erreur brute ; la bascule rétablit le service sur bdd2. |
| V5 | `essais\lancer.cmd v5_reconstruction` | ~18 min | Destruction et reconstruction intégrale sans aucune intervention. |
| V6 | `EXT=e1` puis `essais\lancer.cmd v6_panne_lb` | ~1 min | Le répartiteur tombe : lb2 reprend l'IP virtuelle, le service reste joignable à la même adresse. |

**Si V4 ou V6 est tiré après un autre scénario qui a déjà modifié l'état**,
le dire et reconstruire d'abord : V4 refuse de s'exécuter si bdd2 est déjà
primaire, et c'est un comportement voulu, à expliquer plutôt qu'à subir.

## 4. Questions probables et qui répond

| Question | Réponse courte | Qui doit savoir |
| --- | --- | --- |
| « Montrez que les adresses ne sont pas en dur dans HAProxy. » | `scripts/lb.sh` lit `noeuds_par_role app` depuis `config/noeuds.yml`, engendré par le Vagrantfile. | tous |
| « Passez à 4 serveurs. » | `$env:NB_APP=4; vagrant up` puis V1. La configuration suit seule. | tous |
| « Où sont les mots de passe ? » | Dans `.env`, jamais versionné ; `.env.exemple` donne la liste. L'historique Git ne contient aucun secret. | tous |
| « Prouvez l'idempotence. » | `essais\lancer.cmd r2_idempotence` : deux provisionnements, comparaison de l'empreinte de chaque fichier de `/etc`. | tous |
| « Pourquoi 503 et pas une page blanche ? » | L'application répond un JSON neutre, et HAProxy aussi quand aucun serveur n'est disponible. | OUEDRAOGO, SIMPORE |
| « Que se passe-t-il si on redémarre bdd1 après la bascule ? » | Deux bases accepteraient les écritures : on ne le fait pas, on reconstruit. C'est une limite connue, documentée. | KAGAMBEGA |
| « Votre débit n'augmente pas avec 4 serveurs. » | Les machines partagent un processeur : le résultat est expliqué dans le dossier, pas maquillé. | NIKIEMA |
| « Qui a écrit cette partie ? » | Dire la vérité, y compris quand une tâche a été reprise par un autre membre. | tous |

## 5. Répétition : ce qu'il faut avoir fait au moins une fois

- [ ] Chaque membre a lancé **deux scénarios qu'il n'a pas écrits**.
- [ ] Chaque membre sait expliquer, sans lire, le chemin d'une requête :
      hôte → lb1 → appN → bdd1.
- [ ] Un passage complet chronométré en moins de 20 minutes.
- [ ] Une panne provoquée volontairement pendant la répétition, pour voir ce
      que donne un scénario qui échoue et comment le dire calmement.

## 6. En cas de problème le jour J

| Symptôme | Réaction |
| --- | --- |
| Rien ne répond sur 192.168.61.x | Couper le VPN. |
| `vagrant up` échoue sur la boîte | Vérifier que la boîte est en cache : `vagrant box list`. |
| Machines très lentes | Fermer Docker Desktop et les navigateurs. |
| Un scénario échoue devant l'enseignant | Lire la sortie à voix haute, dire ce qu'on attendait, montrer le fichier de résultat d'une exécution précédente. Une panne expliquée vaut mieux qu'une panne masquée. |
