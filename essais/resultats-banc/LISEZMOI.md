# Sorties d'essai produites sur un banc de conteneurs

**Ces fichiers ne sont pas des mesures de la plateforme Vagrant.** Ils ont
été produits sur un banc qui rejoue la plateforme avec des conteneurs
Docker au lieu de machines virtuelles VirtualBox. Les mesures de la
plateforme elle-même sont dans le dossier voisin, `essais/resultats/`.

## Ce que le banc reproduit fidèlement

- **Les mêmes scripts**, pris tels quels dans `scripts/` : `bdd.sh`,
  `replique.sh`, `app.sh`, `lb.sh`, `bascule.sh`.
- **Les mêmes rôles et le même réseau privé** : bdd1, bdd2, app1…appN, lb1,
  chacun sur sa propre adresse, le répartiteur seul exposé.
- **Les mêmes scénarios**, par les scripts de `essais/`, qui ne savent pas
  s'ils pilotent des conteneurs ou des machines virtuelles.
- **La même distribution**, Ubuntu 24.04, et les mêmes paquets.

## Ce qu'il ne reproduit pas

- **Vagrant lui-même** : ni `vagrant up`, ni le téléchargement de la boîte,
  ni le réseau hôte-seul de VirtualBox. Le scénario V5 n'a donc aucun sens
  sur le banc.
- **systemd** : remplacé par une doublure qui démarre et arrête les mêmes
  services. L'idempotence des fichiers de `/etc` reste vérifiée à
  l'identique, mais pas le comportement des unités au démarrage.
- **L'isolation réelle** : les conteneurs partagent le noyau de l'hôte. Les
  chiffres de débit du scénario V3 ne valent donc que pour le banc, et ne
  doivent pas être comparés à ceux d'une machine virtuelle.

## À quoi ces fichiers servent

À vérifier que les scripts et les scénarios se comportent correctement de
bout en bout après chaque modification, sans monter six machines
virtuelles. C'est ce qui a permis de détecter, entre autres, le
reprovisionnement qui écrasait une base promue, et la mesure de bascule qui
valait zéro seconde parce qu'elle ne basculait plus rien.

**Dans le dossier d'architecture, ces valeurs sont citées comme
vérification fonctionnelle, jamais comme mesures de la plateforme.**

## Comment le banc est monté

Les conteneurs reçoivent le dépôt sur `/vagrant`, exactement comme les
machines virtuelles, et une doublure de `vagrant` traduit `vagrant halt`,
`vagrant up`, `vagrant ssh` et `vagrant provision` en commandes Docker. Les
adresses sont celles de `config/noeuds.yml`, sur un sous-réseau distinct de
celui du groupe pour ne pas entrer en conflit avec une plateforme réelle
qui tournerait en même temps.
